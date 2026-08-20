-- OneDiff: a lightweight git-diff review session built on gitsigns. It opens a
-- quickfix list of changed files and highlights changed lines directly in the
-- real buffers you edit.
--
-- Navigation during a session:
--   * `:cnext` / `:cprev` walk the quickfix (one entry per file)
--   * `<Tab>` / `<S-Tab>` walk hunks across ALL changed files
--   * `(` / `)` (keymappings/git.lua) walk hunks within the current buffer
--   * `<C-S-M>` toggles inline deleted-line virtual lines (start state is the
--     `show_deleted` setting, off by default)
--   * `dd` / `3dd` / visual `d` in the list hide entries for this session only;
--     toggling OneDiff off and on brings the full diff back
--
-- Deleted files are listed (with a red `-` tag) but are not navigation
-- targets: they contribute no hunks, so `<Tab>` skips them, and `<CR>` over
-- one is a no-op rather than opening an empty buffer at the removed path.

local M = {}

-- Safe to require at the top: this module is itself loaded lazily on the first
-- `M` press (plugin_settings/onediff.lua), by which point gitsigns has
-- attached via its own BufReadPre event.
local gitsigns = require("gitsigns")

-- Settings table (base ref, deleted/changed line visibility at session start),
-- populated by plugin_settings/onediff.lua before this module ever loads.
local config = require("my_plugins.onediff.config")

-- Namespace for the quickfix status-tag highlights.
local qf_ns = vim.api.nvim_create_namespace("onediff")

-- Session state. `active` gates the toggle; `augroup` holds the write-refresh
-- autocmd; `saved` snapshots gitsigns settings + `<Tab>` maps restored on
-- close; `hunks`/`file_index` drive cross-file hunk navigation; `qf_id` pins
-- our quickfix list so refresh and cursor sync never touch a list the user
-- switched to mid-session; `dismissed` is the set of paths hidden with `dd`,
-- dropped on close so the next toggle starts from the full diff again.
local session = {
  active = false,
  augroup = nil,
  saved = {},
  hunks = {},
  file_index = {},
  qf_id = nil,
  dismissed = {},
}

-- Standalone changed-line highlight, toggled by `sf` independently of a review
-- session. `active` gates it; `saved` snapshots the gitsigns settings it
-- overrides so toggling off restores them. A full session owns the highlight
-- itself, so this yields (and hands its snapshot over) while one is active.
local highlight = {
  active = false,
  saved = {},
}

-- Colored status tags in the quickfix. New files link to the yellow change
-- color; changed links to the green add color; deleted links to the red delete
-- color. `default` yields to any user override.
vim.api.nvim_set_hl(0, "OneDiffAdded", { link = "GitSignsChange", default = true })
vim.api.nvim_set_hl(0, "OneDiffChanged", { link = "GitSignsAdd", default = true })
vim.api.nvim_set_hl(0, "OneDiffDeleted", { link = "GitSignsDelete", default = true })

-- Per status: the leading symbol and its highlight group. New shows a yellow
-- `*`; changed shows a green `+`; deleted shows a red `-`.
local STATUS = {
  added = { sym = "*", hl = "OneDiffAdded" },
  changed = { sym = "+", hl = "OneDiffChanged" },
  deleted = { sym = "-", hl = "OneDiffDeleted" },
}

-- What every buffer is diffed against. HEAD (not the index) means staged and
-- unstaged changes are both shown.
local BASE_REF = "HEAD"

local normalize = vim.fs.normalize

-- Return the git repository root for the current working directory, or nil
-- when not inside a work tree.
local function git_root()
  local result = vim.system({ "git", "rev-parse", "--show-toplevel" }):wait()

  if result.code ~= 0 then
    return nil
  end

  return vim.trim(result.stdout)
end

-- Collapse a git porcelain XY status pair to one of the three tags the list
-- shows: added (new/untracked), deleted, or changed (modified/renamed/…).
local function status_label(xy)
  if xy == "??" then
    return "added"
  end

  local x, y = xy:sub(1, 1), xy:sub(2, 2)

  if x == "D" or y == "D" then
    return "deleted"
  elseif x == "A" or y == "A" then
    return "added"
  end

  return "changed"
end

-- Parse `git status -z` into an ordered list of { xy, path } records. -z gives
-- NUL-separated fields so paths with spaces or unusual characters survive;
-- rename/copy records carry the original path in the following field (skipped).
local function status_records(root)
  local result = vim.system({
    "git", "-C", root, "-c", "core.quotePath=false",
    "status", "--porcelain", "--untracked-files=all", "-z",
  }):wait()

  local records = {}
  if result.code ~= 0 then
    return records
  end

  local fields = vim.split(result.stdout, "\0", { plain = true })
  local i = 1
  while i <= #fields do
    local field = fields[i]

    if field == "" then
      i = i + 1
    else
      local xy = field:sub(1, 2)
      records[#records + 1] = { xy = xy, path = field:sub(4) }

      if xy:sub(1, 1) == "R" or xy:sub(1, 1) == "C" then
        i = i + 1
      end

      i = i + 1
    end
  end

  return records
end

-- Map each tracked, changed path to the list of its hunk start lines (in the
-- new file), parsed from a single unified=0 diff against HEAD. Untracked files
-- are absent from `git diff`; deleted files contribute no hunks.
local function diff_hunks(root)
  local result = vim.system({
    "git", "-C", root, "-c", "core.quotePath=false",
    "diff", "--unified=0", "--no-color", "-M", BASE_REF,
  }):wait()

  local map = {}
  if result.code ~= 0 then
    return map
  end

  local current
  for line in vim.gsplit(result.stdout, "\n", { plain = true }) do
    if line:match("^diff %-%-git ") then
      current = nil
    else
      local newpath = line:match("^%+%+%+ b/(.+)$")

      if newpath then
        current = newpath
        map[current] = map[current] or {}
      elseif current then
        local start = line:match("^@@ %-%d+.- %+(%d+)")

        if start then
          map[current][#map[current] + 1] = tonumber(start)
        end
      end
    end
  end

  return map
end

-- Status records minus the paths dismissed with `dd`. Filtering here (rather
-- than only in the rendered list) keeps items, hunks, and file_index built from
-- one sequence, so a dismissed file also stops being a `<Tab>` target and the
-- record index stays usable as the quickfix entry index.
local function visible_records(root)
  local records = status_records(root)

  if vim.tbl_isempty(session.dismissed) then
    return records
  end

  local kept = {}

  for _, record in ipairs(records) do
    if not session.dismissed[normalize(root .. "/" .. record.path)] then
      kept[#kept + 1] = record
    end
  end

  return kept
end

-- Read a single line from a file on disk, or "" if unavailable.
local function read_line(path, lnum)
  local ok, lines = pcall(vim.fn.readfile, path, "", lnum)

  if not ok or type(lines) ~= "table" then
    return ""
  end

  return lines[lnum] or ""
end

-- Collect the review state from git in one pass: the quickfix items (one per
-- changed file; the tag is carried in user_data and rendered by qf_textfunc)
-- and the flat, ordered list of hunks used for cross-file `<Tab>` navigation
-- (deleted files excluded).
local function collect()
  local root = git_root()
  if not root then
    return {}, {}, {}
  end

  local records = visible_records(root)
  local hunks_by_path = diff_hunks(root)

  local items = {}
  local hunks = {}
  local file_index = {}

  for i, record in ipairs(records) do
    local label = status_label(record.xy)
    local abs = root .. "/" .. record.path
    file_index[normalize(abs)] = i

    local file_hunks = hunks_by_path[record.path]
    local first = (file_hunks and file_hunks[1]) or 1

    -- Deleted files get a list entry but never a hunk, so `<Tab>` skips them.
    -- The on-disk check backstops the label: a path git still reports as
    -- changed while it is already gone must not become a navigation target.
    -- lstat (not stat) so a changed file that is a symlink to a missing or
    -- external target still counts as present and stays navigable.
    if label == "deleted" or not vim.uv.fs_lstat(abs) then
      items[#items + 1] = {
        filename = abs, lnum = 1, text = "", user_data = { label = "deleted" },
      }
    else
      items[#items + 1] = {
        filename = abs,
        lnum = first,
        text = read_line(abs, first),
        user_data = { label = label },
      }

      if file_hunks and #file_hunks > 0 then
        for _, lnum in ipairs(file_hunks) do
          hunks[#hunks + 1] = { file = abs, lnum = lnum, fidx = i }
        end
      else
        -- Untracked/added file: treat the whole file as one hunk at line 1.
        hunks[#hunks + 1] = { file = abs, lnum = first, fidx = i }
      end
    end
  end

  return items, hunks, file_index
end

-- Render each quickfix entry as `<sym> filepath|lnum| linetext`, leading with
-- the status symbol (setqflist's default renders the file name first). Wired
-- via the list's quickfixtextfunc; the path is shown relative to the working
-- directory.
local function qf_textfunc(info)
  local items = vim.fn.getqflist({ id = info.id, items = 1 }).items
  local out = {}

  for i = info.start_idx, info.end_idx do
    local item = items[i]
    local label = item.user_data and item.user_data.label
    local sym = (label and STATUS[label] and STATUS[label].sym) or " "
    local fname = item.bufnr > 0 and vim.fn.fnamemodify(vim.fn.bufname(item.bufnr), ":.") or ""
    local body = item.text ~= "" and (" " .. item.text) or ""

    out[#out + 1] = string.format("%s %s|%d|%s", sym, fname, item.lnum, body)
  end

  return out
end

-- Return the loaded quickfix buffer number, or nil when there is no quickfix
-- buffer yet or it is not loaded. Centralizes the guard shared by every
-- routine that decorates or rebinds the quickfix buffer.
local function qf_buffer()
  local qf_buf = vim.fn.getqflist({ qfbufnr = 0 }).qfbufnr

  if qf_buf == 0 or not vim.api.nvim_buf_is_loaded(qf_buf) then
    return nil
  end

  return qf_buf
end

-- Whether OneDiff's own quickfix list is the one currently active (and thus
-- shown in the quickfix window). Guards decoration and cursor sync from
-- touching a different list the user switched to mid-session.
local function onediff_list_active()
  return session.qf_id ~= nil
    and vim.fn.getqflist({ id = 0 }).id == session.qf_id
end

-- Color the leading status symbol via buffer extmarks. Extmarks layer above
-- syntax (unlike `:syntax match`, which loses to the built-in qfFileName
-- group); the label comes from each item's user_data, since `+` alone does not
-- distinguish new from changed. Row order matches item order (one line each).
local function color_qf()
  local qf_buf = qf_buffer()

  if not qf_buf
    or vim.fn.getqflist({ winid = 0 }).winid == 0
    or not onediff_list_active() then
    return
  end

  vim.api.nvim_buf_clear_namespace(qf_buf, qf_ns, 0, -1)

  for row, item in ipairs(vim.fn.getqflist({ items = 1 }).items) do
    local label = item.user_data and item.user_data.label
    local status = label and STATUS[label]

    if status then
      vim.api.nvim_buf_set_extmark(qf_buf, qf_ns, row - 1, 0, {
        end_col = 1,
        hl_group = status.hl,
      })
    end
  end
end

-- Open the entry under the cursor, unless it is a deleted file -- those have
-- no content on disk, so the native jump would land in an empty buffer named
-- after the removed path. `:.cc` is what `<CR>` runs natively.
local function open_qf_entry()
  local item = vim.fn.getqflist({ items = 1 }).items[vim.fn.line(".")]

  if not item then
    return
  end

  if item.user_data and item.user_data.label == "deleted" then
    vim.notify("OneDiff: file is deleted -- nothing to open", vim.log.levels.WARN)
    return
  end

  vim.cmd(".cc")
end

-- Park the quickfix window cursor on `line`, clamped to the current list size.
-- Used after a dismissal so the cursor lands on the entry that moved up into
-- the removed one's place instead of jumping to the top.
local function place_qf_cursor(line)
  local qf_win = vim.fn.getqflist({ winid = 0 }).winid
  local size = vim.fn.getqflist({ id = session.qf_id, size = 1 }).size

  if qf_win == 0 or size == 0 then
    return
  end

  pcall(vim.api.nvim_win_set_cursor, qf_win, { math.min(line, size), 0 })
end

-- Hide the entries on the inclusive line range for the rest of the session:
-- their paths join session.dismissed, which visible_records filters out, so the
-- files leave the list and stop contributing hunks. Nothing on disk or in git
-- changes -- the next `M` toggle rebuilds the full diff.
local function dismiss_range(first, last)
  if not session.active or not onediff_list_active() then
    return
  end

  local items = vim.fn.getqflist({ items = 1 }).items

  for line = first, math.min(last, #items) do
    local bufnr = items[line].bufnr

    if bufnr > 0 then
      local path = vim.api.nvim_buf_get_name(bufnr)

      if path ~= "" then
        session.dismissed[normalize(path)] = true
      end
    end
  end

  M.refresh()
  place_qf_cursor(first)
end

-- `dd` (and `3dd`) in the quickfix: dismiss from the cursor down.
local function dismiss_under_cursor()
  local first = vim.fn.line(".")

  dismiss_range(first, first + vim.v.count1 - 1)
end

-- `d` over a visual selection: dismiss every selected entry. Visual mode is
-- still active inside the callback, so the range comes from `v`/`.` and the
-- selection is cleared before the list is rebuilt under it.
local function dismiss_selection()
  local anchor, cursor = vim.fn.line("v"), vim.fn.line(".")

  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)

  dismiss_range(math.min(anchor, cursor), math.max(anchor, cursor))
end

-- Route `<CR>` and double-click in the quickfix buffer through the guarded
-- open, and bind the session-local `dd` / visual `d` dismissal. Buffer-local,
-- so the native behavior is untouched in other lists.
local function guard_qf_keys()
  local qf_buf = qf_buffer()

  if not qf_buf then
    return
  end

  local opts = { buffer = qf_buf, desc = "OneDiff: open entry (deleted files inert)" }
  vim.keymap.set("n", "<CR>", open_qf_entry, opts)
  vim.keymap.set("n", "<2-LeftMouse>", open_qf_entry, opts)

  vim.keymap.set("n", "dd", dismiss_under_cursor,
    { buffer = qf_buf, desc = "OneDiff: dismiss entry for this session" })
  vim.keymap.set("x", "d", dismiss_selection,
    { buffer = qf_buf, desc = "OneDiff: dismiss selected entries for this session" })
end

-- Drop the guarded maps on session close. Neovim reuses the quickfix buffer
-- for later lists, so leaving them behind would shadow `<CR>` there too.
local function unguard_qf_keys()
  local qf_buf = qf_buffer()

  if not qf_buf then
    return
  end

  pcall(vim.keymap.del, "n", "<CR>", { buffer = qf_buf })
  pcall(vim.keymap.del, "n", "<2-LeftMouse>", { buffer = qf_buf })
  pcall(vim.keymap.del, "n", "dd", { buffer = qf_buf })
  pcall(vim.keymap.del, "x", "d", { buffer = qf_buf })
end

-- Re-apply everything that depends on the rendered quickfix buffer.
local function decorate_qf()
  color_qf()
  guard_qf_keys()
end

-- Point the quickfix list, and its window when open, at `fidx` without stealing
-- focus -- so the selected entry tracks `<Tab>` hunk navigation across files.
local function sync_qf_cursor(fidx)
  if not fidx or not session.qf_id then
    return
  end

  vim.fn.setqflist({}, "r", { id = session.qf_id, idx = fidx })

  -- Only move the visible cursor when our list is the one on screen; otherwise
  -- we'd scroll an unrelated quickfix the user switched to.
  if not onediff_list_active() then
    return
  end

  local qf_win = vim.fn.getqflist({ winid = 0 }).winid

  if qf_win ~= 0 then
    pcall(vim.api.nvim_win_set_cursor, qf_win, { fidx, 0 })
  end
end

-- Rebuild the quickfix list and hunk-navigation state. `open` opens the
-- quickfix window; `keep_idx` restores the pre-rebuild cursor position (used on
-- refresh so a save does not jump the list back to the top).
local function populate(open, keep_idx)
  local prev_idx = keep_idx and session.qf_id
    and vim.fn.getqflist({ id = session.qf_id, idx = 0 }).idx or nil
  local items, hunks, file_index = collect()

  session.hunks = hunks
  session.file_index = file_index

  local what = { items = items, title = "OneDiff", quickfixtextfunc = qf_textfunc }
  if prev_idx and #items > 0 then
    what.idx = math.min(prev_idx, #items)
  end

  if keep_idx and session.qf_id then
    -- Replace our own list by id on refresh so we never clobber a different
    -- quickfix the user switched to mid-session.
    what.id = session.qf_id
    vim.fn.setqflist({}, "r", what)
  else
    -- Fresh list on open; remember its id so later refreshes and cursor syncs
    -- target it rather than whatever list happens to be current.
    vim.fn.setqflist({}, " ", what)
    session.qf_id = vim.fn.getqflist({ id = 0 }).id
  end

  if open then
    vim.cmd("copen")
  end

  -- Recolor and rebind after the quickfix buffer has re-rendered its lines.
  vim.schedule(decorate_qf)
end

-- Return the first hunk ordered after (fidx, line), wrapping to the first.
local function next_hunk_after(fidx, line)
  for _, hunk in ipairs(session.hunks) do
    if hunk.fidx > fidx or (hunk.fidx == fidx and hunk.lnum > line) then
      return hunk
    end
  end

  return session.hunks[1]
end

-- Return the last hunk ordered before (fidx, line), wrapping to the last.
local function prev_hunk_before(fidx, line)
  local prev
  for _, hunk in ipairs(session.hunks) do
    if hunk.fidx < fidx or (hunk.fidx == fidx and hunk.lnum < line) then
      prev = hunk
    else
      break
    end
  end

  return prev or session.hunks[#session.hunks]
end

-- Whether a window is showing one of this review's changed files (its buffer
-- path is tracked in file_index). Lets file_window prefer reusing a review
-- window over hijacking an unrelated buffer.
local function shows_reviewed_file(win)
  local name = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win))

  return session.file_index[normalize(name)] ~= nil
end

-- Return a window in the current tabpage to load a changed file into. Prefers a
-- window already showing one of the review's changed files (so `<Tab>` reuses
-- the review window instead of clobbering an unrelated buffer), then the
-- previous window, then any normal window, then any non-quickfix window. nil
-- when no usable window is open.
local function file_window()
  local previous = vim.fn.win_getid(vim.fn.winnr("#"))
  local previous_ok = previous ~= 0
    and vim.bo[vim.api.nvim_win_get_buf(previous)].buftype == ""

  if previous_ok and shows_reviewed_file(previous) then
    return previous
  end

  local review_win, first_normal, fallback

  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buftype = vim.bo[vim.api.nvim_win_get_buf(win)].buftype

    if buftype == "" then
      first_normal = first_normal or win

      if not review_win and shows_reviewed_file(win) then
        review_win = win
      end
    elseif buftype ~= "quickfix" and not fallback then
      fallback = win
    end
  end

  return review_win or (previous_ok and previous) or first_normal or fallback
end

-- Jump to a hunk, opening its file if it is not the current buffer.
local function jump_to(hunk)
  if not hunk then
    return
  end

  -- From the quickfix window `:edit` would load the file over the list itself.
  -- Hop to a normal window first so the list survives and Tab keeps walking
  -- hunks in the file rather than the quickfix buffer.
  if vim.bo.buftype ~= "" then
    local target = file_window()

    if not target then
      return
    end

    vim.api.nvim_set_current_win(target)
  end

  if normalize(vim.api.nvim_buf_get_name(0)) ~= normalize(hunk.file) then
    vim.cmd("edit " .. vim.fn.fnameescape(hunk.file))
  end

  local last = vim.api.nvim_buf_line_count(0)
  vim.api.nvim_win_set_cursor(0, { math.min(hunk.lnum, last), 0 })
  vim.cmd("normal! zz")

  sync_qf_cursor(hunk.fidx)
end

-- Whether a buffer is a normal, named file buffer (not a dashboard, quickfix,
-- terminal, or empty start screen).
local function is_real_file(buf)
  return vim.bo[buf].buftype == "" and vim.api.nvim_buf_get_name(buf) ~= ""
end

-- Jump to the next hunk across all changed files (bound to `<Tab>`).
function M.next_hunk()
  if not session.active or #session.hunks == 0 then
    return
  end

  local fidx = session.file_index[normalize(vim.api.nvim_buf_get_name(0))]
  if not fidx then
    jump_to(session.hunks[1])
    return
  end

  jump_to(next_hunk_after(fidx, vim.api.nvim_win_get_cursor(0)[1]))
end

-- Jump to the previous hunk across all changed files (bound to `<S-Tab>`).
function M.prev_hunk()
  if not session.active or #session.hunks == 0 then
    return
  end

  local fidx = session.file_index[normalize(vim.api.nvim_buf_get_name(0))]
  if not fidx then
    jump_to(session.hunks[#session.hunks])
    return
  end

  jump_to(prev_hunk_before(fidx, vim.api.nvim_win_get_cursor(0)[1]))
end

-- Toggle inline deleted-line virtual lines for the session (bound to
-- `<C-S-M>`). Starts from the `show_deleted` setting; refresh re-renders open
-- buffers.
function M.toggle_deleted()
  if not session.active then
    return
  end

  gitsigns.toggle_deleted()
  gitsigns.refresh()
end

-- Bind the session keymaps (cross-file hunk nav + deleted-line toggle), saving
-- any prior mapping so close() can restore it (default `<Tab>` is
-- jumplist-forward; `<C-S-M>` is usually unmapped). Note: Ctrl+Shift+M is
-- only distinct from `<CR>`/`<C-M>` when the terminal speaks the kitty
-- keyboard protocol (kitty does; newer alacritty does too).
local function install_session_keymaps()
  session.saved.tab = vim.fn.maparg("<Tab>", "n", false, true)
  session.saved.stab = vim.fn.maparg("<S-Tab>", "n", false, true)
  session.saved.del = vim.fn.maparg("<C-S-M>", "n", false, true)

  vim.keymap.set("n", "<Tab>", function() M.next_hunk() end,
    { desc = "OneDiff: next hunk across all files" })
  vim.keymap.set("n", "<S-Tab>", function() M.prev_hunk() end,
    { desc = "OneDiff: prev hunk across all files" })
  vim.keymap.set("n", "<C-S-M>", function() M.toggle_deleted() end,
    { desc = "OneDiff: toggle deleted lines" })
end

-- Remove the session keymaps and restore any prior mapping.
local function remove_session_keymaps()
  pcall(vim.keymap.del, "n", "<Tab>")
  pcall(vim.keymap.del, "n", "<S-Tab>")
  pcall(vim.keymap.del, "n", "<C-S-M>")

  for _, saved in ipairs({ session.saved.tab, session.saved.stab, session.saved.del }) do
    if saved and not vim.tbl_isempty(saved) then
      vim.fn.mapset("n", false, saved)
    end
  end
end

-- End the session when OneDiff's quickfix window is closed, so the changed-line
-- highlights do not linger after the list is gone. Deferred: tearing windows
-- down synchronously inside WinClosed hits textlock. close() also deletes this
-- augroup before it runs cclose, so the teardown cannot re-trigger the event.
local function on_qf_window_closed(args)
  if not session.active then
    return
  end

  local win = tonumber(args.match)

  if not win or not vim.api.nvim_win_is_valid(win) then
    return
  end

  if vim.bo[vim.api.nvim_win_get_buf(win)].buftype == "quickfix" then
    vim.schedule(function()
      M.close()
    end)
  end
end

-- Session autocmds: refresh the quickfix list after every write so it tracks
-- edits and staging, and end the session when its window is closed. Both torn
-- down in close().
local function setup_autocmds()
  session.augroup = vim.api.nvim_create_augroup("OneDiff", { clear = true })

  vim.api.nvim_create_autocmd("BufWritePost", {
    group = session.augroup,
    desc = "Refresh OneDiff quickfix on save",
    callback = function()
      M.refresh()
    end,
  })

  vim.api.nvim_create_autocmd("WinClosed", {
    group = session.augroup,
    desc = "End OneDiff session when its quickfix window closes",
    callback = on_qf_window_closed,
  })
end

-- Snapshot into `store` the gitsigns settings the highlight overrides, so they
-- can later be restored to exactly what was there before (not just this
-- config's defaults). Reads the live gitsigns config table directly -- there
-- is no public getter.
local function snapshot_gitsigns(store)
  local config = require("gitsigns.config").config
  store.linehl = config.linehl
  store.show_deleted = config.show_deleted
  store.base = config.base
end

-- Restore the gitsigns settings snapshotted in `store` and re-render open
-- buffers.
local function restore_gitsigns(store)
  local config = require("gitsigns.config").config
  config.linehl = store.linehl
  config.show_deleted = store.show_deleted

  -- change_base re-diffs buffers against the restored base; refresh re-renders
  -- them with the restored line-highlight / deleted settings.
  gitsigns.change_base(store.base, true)
  gitsigns.refresh()
end

-- Turn on the full-line add/change highlight. Changed lines link to the
-- add-line group so they render the same green as added lines. Shared by the
-- review session (M.open) and the standalone toggle (`sf`).
local function enable_change_highlight()
  vim.api.nvim_set_hl(0, "GitSignsChangeLn", { link = "GitSignsAddLn" })
  gitsigns.toggle_linehl(true)
end

-- Re-diff against the configured base and re-render, so already-attached
-- buffers (including the current one) pick up the settings just applied -- the
-- gitsigns toggle_* setters only mutate its config table, so without refresh()
-- only buffers opened afterward would show them. One call renders the line
-- highlight and the deleted-line setting together.
local function render_against_base()
  gitsigns.change_base(BASE_REF, true)
  gitsigns.refresh()
end

-- Start a review session: highlight changed lines against HEAD in every real
-- buffer and open the quickfix list of changed files. Re-invoking while active
-- just refreshes.
function M.open()
  if session.active then
    M.refresh()
    return
  end

  -- Capture where the cursor starts so we can decide, after the list is built,
  -- whether to keep it here or move it. Starting from a non-file buffer
  -- (dashboard, empty start screen) auto-opens the first changed file so the
  -- review has something to show.
  local current_buf = vim.api.nvim_get_current_buf()
  local current_name = normalize(vim.api.nvim_buf_get_name(current_buf))
  local autonav = not is_real_file(current_buf)

  session.active = true
  session.dismissed = {}

  -- Adopt an in-progress standalone highlight (`sf`): reuse its pre-highlight
  -- snapshot so close() restores the true original state rather than the
  -- already-highlighted one. Otherwise snapshot the live settings now.
  if highlight.active then
    session.saved = highlight.saved
    highlight.active = false
  else
    session.saved = {}
    snapshot_gitsigns(session.saved)
  end

  install_session_keymaps()

  -- Keep vim-qfedit off our list: it makes the quickfix buffer modifiable and
  -- re-parses it on TextChanged against the default `file|lnum| text` render,
  -- which our leading status symbol breaks -- an accidental edit would then
  -- match no entry and wipe the list. Our own `dd` covers the same need.
  session.saved.qfedit_enable = vim.g.qfedit_enable
  vim.g.qfedit_enable = 0

  -- Apply the configured deleted-line visibility and the changed-line
  -- highlight (`<C-S-M>` and `sf` still flip them by hand), then re-render open
  -- buffers against the base. All restored on close.
  gitsigns.toggle_deleted(config.options.show_deleted)
  enable_change_highlight()

  render_against_base()

  populate(true, false)

  local current_fidx = session.file_index[current_name]

  if autonav and #session.hunks > 0 then
    -- copen focused the quickfix; step back to the window it opened from and
    -- load the first changed file there.
    vim.cmd("wincmd p")
    if vim.bo.buftype ~= "quickfix" then
      jump_to(session.hunks[1])
    end
  elseif current_fidx then
    -- The current buffer is one of the changed files: its highlight is already
    -- applied, so keep the focus in the list copen just opened and park the
    -- cursor on the matching entry -- the review starts from the file on screen
    -- with the list ready for `dd` / `<CR>`.
    sync_qf_cursor(current_fidx)
  end

  setup_autocmds()
end

-- Rebuild the quickfix list in place (on every write, or on a re-toggle while
-- active) without stealing focus or losing the cursor position. The session
-- base stays HEAD, so only the list contents are refreshed.
function M.refresh()
  if not session.active then
    return
  end

  populate(false, true)
end

-- End the session: restore the snapshotted gitsigns settings and session maps,
-- drop the write autocmd, and close the quickfix window.
function M.close()
  if not session.active then
    return
  end

  session.active = false
  remove_session_keymaps()
  unguard_qf_keys()
  restore_gitsigns(session.saved)
  vim.g.qfedit_enable = session.saved.qfedit_enable

  if session.augroup then
    vim.api.nvim_del_augroup_by_id(session.augroup)
    session.augroup = nil
  end

  vim.cmd("cclose")
  session.hunks = {}
  session.file_index = {}
  session.qf_id = nil
  session.dismissed = {}
end

-- Toggle the review session on/off (bound to `M`).
function M.toggle()
  if session.active then
    M.close()
  else
    M.open()
  end
end

-- Turn on the changed-line highlight and re-diff every buffer against the base
-- (bound to `sf`), independent of the review session. Pressing it again is a
-- refresh, not a toggle: the highlight picks up commits, stages, and checkouts
-- made since it went on. The pre-highlight gitsigns settings are snapshotted
-- once, on the first call, so a later session close restores the true original
-- state. No-op while a session is active, since the session already renders the
-- highlight and owns its teardown.
function M.refresh_highlight()
  if session.active then
    vim.notify("OneDiff: session active -- highlight already on", vim.log.levels.INFO)
    return
  end

  if not highlight.active then
    highlight.active = true
    highlight.saved = {}
    snapshot_gitsigns(highlight.saved)
  end

  enable_change_highlight()
  render_against_base()
end

-- Whether a review session is currently running.
function M.is_active()
  return session.active
end

return M
