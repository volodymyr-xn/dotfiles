local M = {}

-- Files larger than this skip treesitter and per-line extmarks; an info header is rendered instead.
local SIZE_GATE_BYTES = 2 * 1024 * 1024
-- Per-line extmark loop is O(changed lines); above this many lines we skip syntax + bound the loop.
local TREESITTER_LINE_GATE = 10000

local function read_file_sync(path)
  local fd = vim.loop.fs_open(path, "r", 438)
  if not fd then return nil end

  local stat = vim.loop.fs_fstat(fd)
  if not stat then
    vim.loop.fs_close(fd)
    return nil
  end

  local data = vim.loop.fs_read(fd, stat.size, 0) or ""
  vim.loop.fs_close(fd)
  return data
end

local function split_lines(data)
  local lines = vim.split(data, "\n", { plain = true })
  -- Trailing newline produces an empty final element; drop it so line count matches file.
  if lines[#lines] == "" then
    table.remove(lines)
  end
  return lines
end

local function buffer_has_treesitter(buf)
  local ok, hl = pcall(require, "vim.treesitter.highlighter")
  if not ok then return false end
  return hl.active and hl.active[buf] ~= nil
end

function M.render_current()
  local session = require("my_plugins.onediff.session")
  local git_ops = require("my_plugins.onediff.git_ops")
  local diff_parse = require("my_plugins.onediff.diff_parse")
  local settings = require("my_plugins.onediff.settings")

  local file = session.get_current_file()
  if not file then
    vim.notify("OneDiff: No changed files found", vim.log.levels.INFO)
    return
  end

  local base_ref = session.get_base_ref()

  if git_ops.is_binary_file(file.path, base_ref, file.full_path) then
    session.set_hunks({})
    M.open_binary_placeholder(file)
    return
  end

  if file.status == "untracked" then
    session.set_hunks({})
    M.open_file_with_diff(file, {}, base_ref)
    return
  end

  local diff_text = git_ops.get_file_diff(file.path, base_ref)
  local hunks = diff_parse.parse_hunks(diff_text)
  session.set_hunks(hunks)

  local staged_diff = git_ops.get_staged_diff(file.path, base_ref)
  local staged_hunks = diff_parse.parse_hunks(staged_diff)
  session.set_staged_hunks(staged_hunks)

  M.open_file_with_diff(file, hunks, base_ref, staged_hunks)
end

-- Acquire the one reusable scratch buffer; create on first use, otherwise wipe its contents.
local function acquire_diff_buf(session, settings)
  local buf = session.get_diff_buf()
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    buf = vim.api.nvim_create_buf(false, true)
    session.set_diff_buf(buf)
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "hide"
    vim.bo[buf].swapfile = false
  else
    vim.bo[buf].modifiable = true
    -- Clear extmarks from every namespace this plugin writes to (settings ns + onediff_binary).
    vim.api.nvim_buf_clear_namespace(buf, -1, 0, -1)
    -- Detach any treesitter highlighter from the previous render so the next file's parser can attach.
    pcall(vim.treesitter.stop, buf)
  end
  return buf
end

local function configure_diff_buf(buf, target_win, file)
  vim.b[buf].is_onediff_buffer = true
  vim.b[buf].onediff_file_path = file.path
  vim.wo[target_win].statusline = " %#OneDiffNonText#[OneDiff] %#OneDiffStatusLinePath#" .. file.path
  vim.keymap.set("n", '"', "<Nop>", { buffer = buf, silent = true })
  vim.keymap.set("n", "m", function() require("my_plugins.onediff").toggle_zoom() end, { buffer = buf, silent = true })
end

local function attach_syntax(buf, file_path, line_count)
  if line_count > TREESITTER_LINE_GATE then
    return
  end

  local ft = vim.filetype.match({ filename = file_path })
  if not ft then return end

  -- Default path: Vim's regex `:syntax` — lazy, ships with every filetype, no parser-install dance.
  if not require("my_plugins.onediff.settings").current.use_treesitter then
    vim.bo[buf].syntax = ft
    return
  end

  if buffer_has_treesitter(buf) then
    return
  end

  -- Treesitter is opt-in: defer parsing so the first paint shows diff highlights immediately.
  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(buf) then return end
    local lang = vim.treesitter.language.get_lang(ft) or ft
    if not pcall(vim.treesitter.start, buf, lang) then
      vim.bo[buf].syntax = ft
    end
  end)
end

function M.open_file_with_diff(file, hunks, base_ref, staged_hunks)
  local session = require("my_plugins.onediff.session")
  local settings = require("my_plugins.onediff.settings")
  local diff_parse = require("my_plugins.onediff.diff_parse")

  local sidebar_win = session.get_sidebar_win()
  local target_win = nil

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if win ~= sidebar_win and vim.api.nvim_win_is_valid(win) then
      target_win = win
      break
    end
  end

  if not target_win then
    vim.cmd("vsplit")
    target_win = vim.api.nvim_get_current_win()
  end

  vim.api.nvim_set_current_win(target_win)

  if file.status == "deleted" then
    M.render_deleted_file(file, base_ref, target_win)
    return
  end

  local saved_lazyredraw = vim.o.lazyredraw
  vim.o.lazyredraw = true

  local buf = acquire_diff_buf(session, settings)
  if vim.api.nvim_win_get_buf(target_win) ~= buf then
    vim.api.nvim_win_set_buf(target_win, buf)
  end

  configure_diff_buf(buf, target_win, file)

  -- fs_stat lets us pick an oversize path before reading the whole file into memory.
  local stat = vim.loop.fs_stat(file.full_path)
  local oversize = stat and stat.size > SIZE_GATE_BYTES

  local lines
  if oversize then
    local size_mb = string.format("%.1f", (stat.size or 0) / 1024 / 1024)
    lines = {
      "",
      "  OneDiff: file is " .. size_mb .. " MB — diff view skipped.",
      "  Inline highlights and syntax are disabled above " ..
        string.format("%.0f", SIZE_GATE_BYTES / 1024 / 1024) .. " MB.",
      "",
      "  Press `o` to open the file in a new tab.",
    }
  else
    local data = read_file_sync(file.full_path) or ""
    lines = split_lines(data)
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  pcall(vim.api.nvim_buf_set_name, buf, "[OneDiff] " .. file.path)

  if not oversize then
    attach_syntax(buf, file.path, #lines)
  end

  vim.bo[buf].modified = false
  vim.bo[buf].modifiable = false

  M.setup_buffer_keymaps(buf)

  if not oversize then
    if file.status == "untracked" then
      M.highlight_untracked_file(buf)
    else
      M.apply_inline_diff(buf, hunks, file, base_ref, staged_hunks)
    end
  end

  local first_change_line = nil
  if not oversize and hunks and #hunks > 0 then
    local change_blocks = diff_parse.get_change_lines_in_buffer(hunks)
    if #change_blocks > 0 then
      first_change_line = change_blocks[1].start
    end
  end

  if first_change_line then
    local line_count = vim.api.nvim_buf_line_count(buf)
    if first_change_line >= 1 and first_change_line <= line_count then
      vim.api.nvim_win_set_cursor(target_win, { first_change_line, 0 })
      vim.cmd("normal! zz")
    end
  end

  vim.o.lazyredraw = saved_lazyredraw
  vim.cmd("redraw")
end

function M.open_binary_placeholder(file)
  local session = require("my_plugins.onediff.session")
  local settings = require("my_plugins.onediff.settings")

  local sidebar_win = session.get_sidebar_win()
  local target_win = nil
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if win ~= sidebar_win and vim.api.nvim_win_is_valid(win) then
      target_win = win
      break
    end
  end

  if not target_win then
    vim.cmd("vsplit")
    target_win = vim.api.nvim_get_current_win()
  end

  vim.api.nvim_set_current_win(target_win)

  local buf = acquire_diff_buf(session, settings)
  if vim.api.nvim_win_get_buf(target_win) ~= buf then
    vim.api.nvim_win_set_buf(target_win, buf)
  end

  configure_diff_buf(buf, target_win, file)

  local win_width = vim.api.nvim_win_get_width(target_win)
  local win_height = vim.api.nvim_win_get_height(target_win)

  local msg = "Preview for binary files unavailable"
  local pad = string.rep(" ", math.max(0, math.floor((win_width - #msg) / 2)))
  local blank = ""
  local lines = {}
  for _ = 1, math.floor(win_height / 2) - 1 do
    table.insert(lines, blank)
  end
  table.insert(lines, pad .. msg)

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  pcall(vim.api.nvim_buf_set_name, buf, "[binary] " .. file.path)

  local ns = vim.api.nvim_create_namespace("onediff_binary")
  local msg_line = math.floor(win_height / 2) - 1
  vim.api.nvim_buf_set_extmark(buf, ns, msg_line, #pad, {
    end_col = #pad + #msg,
    hl_group = "Comment",
  })

  M.setup_buffer_keymaps(buf)
end

function M.setup_buffer_keymaps(buf)
  local onediff = require("my_plugins.onediff")
  local opts = { buffer = buf, silent = true, nowait = true }

  vim.keymap.set("n", "<Tab>", onediff.goto_next_change, opts)
  vim.keymap.set("n", "<S-Tab>", onediff.goto_prev_change, opts)
  vim.keymap.set("n", "<C-i>", onediff.goto_next_change, opts)
  vim.keymap.set("n", "<C-o>", onediff.goto_prev_change, opts)
  vim.keymap.set("n", ")", onediff.goto_next_change, opts)
  vim.keymap.set("n", "(", onediff.goto_prev_change, opts)
  -- Jump back to the sidebar window from the diff view.
  vim.keymap.set("n", "<C-0>", onediff.focus_sidebar, opts)
  vim.keymap.set("n", "q", onediff.open_file_picker, opts)
  vim.keymap.set("n", "<C-q>", onediff.close, opts)
  vim.keymap.set("n", "<C-c>", function() vim.schedule(onediff.close) end, opts)
  vim.keymap.set("n", "<Esc>", onediff.close, opts)
  vim.keymap.set("n", "<Leader>e", onediff.reload_current_file, opts)
  vim.keymap.set("n", "sf", onediff.open_or_focus_and_refresh, opts)
  vim.keymap.set("n", "o", onediff.open_current_file_in_new_tab, opts)
  vim.keymap.set("n", "i", onediff.open_current_file_in_new_tab, opts)
  vim.keymap.set("n", "sn", onediff.stage_hunk, opts)
  vim.keymap.set("n", "sm", onediff.unstage_hunk, opts)
  -- Toggle treesitter highlighting for the current OneDiff session.
  vim.keymap.set("n", "si", onediff.toggle_treesitter, opts)
  vim.keymap.set("n", "`", function()
    local path = vim.b[buf].onediff_file_path
    if path then
      vim.fn.setreg("+", path)
      vim.notify(path, vim.log.levels.INFO)
    end
  end, opts)

  local group = vim.api.nvim_create_augroup("OneDiffBuffer_" .. buf, { clear = true })

  vim.api.nvim_create_autocmd({"BufWinEnter", "WinEnter"}, {
    group = group,
    buffer = buf,
    callback = function(args)
      local win = vim.api.nvim_get_current_win()
      vim.wo[win].number = true
      vim.wo[win].relativenumber = false
      vim.wo[win].signcolumn = "yes"
      local path = vim.b[buf].onediff_file_path
      if path then
        vim.wo[win].statusline = " %#OneDiffNonText#[OneDiff] %#OneDiffStatusLinePath#" .. path
      end
    end,
  })
end

function M.render_deleted_file(file, base_ref, target_win)
  local git_ops = require("my_plugins.onediff.git_ops")
  local settings = require("my_plugins.onediff.settings")
  local session = require("my_plugins.onediff.session")

  local content = git_ops.get_base_content(file.path, base_ref)
  if not content then
    vim.notify("OneDiff: Could not retrieve deleted file content", vim.log.levels.WARN)
    return
  end

  local buf = acquire_diff_buf(session, settings)
  if vim.api.nvim_win_get_buf(target_win) ~= buf then
    vim.api.nvim_win_set_buf(target_win, buf)
  end

  configure_diff_buf(buf, target_win, file)

  local lines = vim.split(content, "\n", { plain = true })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  vim.bo[buf].modifiable = false
  pcall(vim.api.nvim_buf_set_name, buf, "[deleted] " .. file.path)

  attach_syntax(buf, file.path, #lines)

  local ns = settings.get_ns()
  local hl = settings.get("highlights")
  local line_count = #lines

  -- One nvim_buf_call avoids per-extmark window revalidation when the buffer isn't the current one.
  vim.api.nvim_buf_call(buf, function()
    for i = 0, line_count - 1 do
      vim.api.nvim_buf_set_extmark(buf, ns, i, 0, {
        line_hl_group = hl.line_delete,
      })
    end
  end)

  M.setup_buffer_keymaps(buf)
end

local function is_hunk_staged(hunk, staged_hunks)
  if not staged_hunks or #staged_hunks == 0 then return false end

  local hunk_adds = {}
  for _, change in ipairs(hunk.changes) do
    if change.type == "add" then
      table.insert(hunk_adds, change.text)
    end
  end

  if #hunk_adds == 0 then return false end

  for _, staged_hunk in ipairs(staged_hunks) do
    local staged_adds = {}
    for _, change in ipairs(staged_hunk.changes) do
      if change.type == "add" then
        table.insert(staged_adds, change.text)
      end
    end

    if #staged_adds == #hunk_adds then
      local match = true
      for i, line in ipairs(hunk_adds) do
        if staged_adds[i] ~= line then
          match = false
          break
        end
      end
      if match then return true end
    end
  end

  return false
end

function M.apply_inline_diff(buf, hunks, file, base_ref, staged_hunks)
  local settings = require("my_plugins.onediff.settings")

  if not hunks or #hunks == 0 then
    return
  end

  local ns = settings.get_ns()
  local hl = settings.get("highlights")
  local buf_line_count = vim.api.nvim_buf_line_count(buf)

  -- All extmark writes run inside one buf_call so window revalidation happens at most once.
  vim.api.nvim_buf_call(buf, function()
    for _, hunk in ipairs(hunks) do
      local new_line_idx = hunk.new_start - 1
      local deleted_lines = {}
      local deleted_attach_line = nil
      local hunk_is_staged = is_hunk_staged(hunk, staged_hunks)
      local add_hl = hunk_is_staged and hl.line_staged or hl.line_add

      local function flush_deleted_lines()
        if #deleted_lines == 0 then
          return
        end
        if buf_line_count == 0 then
          deleted_lines = {}
          deleted_attach_line = nil
          return
        end

        local attach_line = math.min(deleted_attach_line, buf_line_count - 1)
        local virt_lines = {}
        for _, text in ipairs(deleted_lines) do
          table.insert(virt_lines, { { text, hl.line_delete } })
        end
        vim.api.nvim_buf_set_extmark(buf, ns, attach_line, 0, {
          virt_lines = virt_lines,
          virt_lines_above = deleted_attach_line > 0,
        })

        deleted_lines = {}
        deleted_attach_line = nil
      end

      for _, change in ipairs(hunk.changes) do
        if change.type == "context" then
          flush_deleted_lines()
          new_line_idx = new_line_idx + 1
        elseif change.type == "add" then
          flush_deleted_lines()
          if new_line_idx >= 0 and new_line_idx < buf_line_count then
            vim.api.nvim_buf_set_extmark(buf, ns, new_line_idx, 0, {
              line_hl_group = add_hl,
            })
          end
          new_line_idx = new_line_idx + 1
        elseif change.type == "delete" then
          if deleted_attach_line == nil then
            deleted_attach_line = math.max(new_line_idx, 0)
          end
          table.insert(deleted_lines, change.text)
        end
      end

      flush_deleted_lines()
    end
  end)
end

function M.highlight_untracked_file(buf)
  local settings = require("my_plugins.onediff.settings")
  local ns = settings.get_ns()
  local hl = settings.get("highlights")

  local line_count = vim.api.nvim_buf_line_count(buf)
  vim.api.nvim_buf_call(buf, function()
    for i = 0, line_count - 1 do
      vim.api.nvim_buf_set_extmark(buf, ns, i, 0, {
        line_hl_group = hl.line_add,
      })
    end
  end)
end

local function build_patch_for_hunk(file_path, hunk)
  local lines = {}
  table.insert(lines, string.format("diff --git a/%s b/%s", file_path, file_path))
  table.insert(lines, string.format("--- a/%s", file_path))
  table.insert(lines, string.format("+++ b/%s", file_path))

  local old_count = 0
  local new_count = 0
  for _, change in ipairs(hunk.changes) do
    if change.type == "context" then
      old_count = old_count + 1
      new_count = new_count + 1
    elseif change.type == "add" then
      new_count = new_count + 1
    elseif change.type == "delete" then
      old_count = old_count + 1
    end
  end

  table.insert(lines, string.format("@@ -%d,%d +%d,%d @@", hunk.old_start, old_count, hunk.new_start, new_count))

  for _, change in ipairs(hunk.changes) do
    if change.type == "context" then
      table.insert(lines, " " .. change.text)
    elseif change.type == "add" then
      table.insert(lines, "+" .. change.text)
    elseif change.type == "delete" then
      table.insert(lines, "-" .. change.text)
    end
  end

  table.insert(lines, "")
  return table.concat(lines, "\n")
end

function M.stage_current_hunk()
  local session = require("my_plugins.onediff.session")
  local git_ops = require("my_plugins.onediff.git_ops")
  local controls = require("my_plugins.onediff.controls")

  local file = session.get_current_file()
  if not file then return end

  local hunks = session.get_hunks()
  local staged_hunks = session.get_staged_hunks()

  local hunk_idx = controls.get_current_hunk_index()
  if hunk_idx == 0 then
    vim.notify("OneDiff: No hunk at cursor", vim.log.levels.INFO)
    return
  end

  local hunk = hunks[hunk_idx]
  if not hunk then return end

  if is_hunk_staged(hunk, staged_hunks) then
    vim.notify("OneDiff: Hunk already staged", vim.log.levels.INFO)
    return
  end

  local git_root = git_ops.get_root()
  if not git_root then return end

  local patch = build_patch_for_hunk(file.path, hunk)
  git_ops.stage_hunk(git_root, patch)

  require("my_plugins.onediff").open_or_focus_and_refresh()
end

function M.unstage_current_hunk()
  local session = require("my_plugins.onediff.session")
  local git_ops = require("my_plugins.onediff.git_ops")
  local controls = require("my_plugins.onediff.controls")

  local file = session.get_current_file()
  if not file then return end

  local hunks = session.get_hunks()
  local staged_hunks = session.get_staged_hunks()

  local hunk_idx = controls.get_current_hunk_index()
  if hunk_idx == 0 then
    vim.notify("OneDiff: No hunk at cursor", vim.log.levels.INFO)
    return
  end

  local hunk = hunks[hunk_idx]
  if not hunk then return end

  if not is_hunk_staged(hunk, staged_hunks) then
    vim.notify("OneDiff: Hunk is not staged", vim.log.levels.INFO)
    return
  end

  local matching_staged_hunk = nil
  for _, sh in ipairs(staged_hunks) do
    if is_hunk_staged(hunk, { sh }) then
      matching_staged_hunk = sh
      break
    end
  end

  if not matching_staged_hunk then
    vim.notify("OneDiff: Cannot find staged hunk", vim.log.levels.WARN)
    return
  end

  local git_root = git_ops.get_root()
  if not git_root then return end

  local patch = build_patch_for_hunk(file.path, matching_staged_hunk)
  git_ops.unstage_hunk(git_root, patch)

  require("my_plugins.onediff").open_or_focus_and_refresh()
end

function M.clear_buffer_highlights(buf)
  local settings = require("my_plugins.onediff.settings")
  local ns = settings.get_ns()
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
end

function M.clear_all()
  local session = require("my_plugins.onediff.session")

  -- Buffer is bufhidden=hide so it survives window switches; close fully wipes it.
  local diff_buf = session.get_diff_buf()
  if diff_buf and vim.api.nvim_buf_is_valid(diff_buf) then
    M.clear_buffer_highlights(diff_buf)
    vim.api.nvim_buf_delete(diff_buf, { force = true })
  end
end

return M
