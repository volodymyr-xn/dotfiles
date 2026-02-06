local M = {}

function M.render_current()
  local session = require("my_extensions.onediff.session")
  local git_ops = require("my_extensions.onediff.git_ops")
  local diff_parse = require("my_extensions.onediff.diff_parse")
  local settings = require("my_extensions.onediff.settings")

  local file = session.get_current_file()
  if not file then
    vim.notify("OneDiff: No changed files found", vim.log.levels.INFO)
    return
  end

  local base_ref = session.get_base_ref()
  
  if file.status == "untracked" then
    session.set_hunks({})
    M.open_file_with_diff(file, {}, base_ref)
    return
  end
  
  local diff_text = git_ops.get_file_diff(file.path, base_ref)
  local hunks = diff_parse.parse_hunks(diff_text)
  session.set_hunks(hunks)

  M.open_file_with_diff(file, hunks, base_ref)
end

function M.open_file_with_diff(file, hunks, base_ref)
  local git_ops = require("my_extensions.onediff.git_ops")
  local diff_parse = require("my_extensions.onediff.diff_parse")
  local session = require("my_extensions.onediff.session")
  local settings = require("my_extensions.onediff.settings")
  local sidebar = require("my_extensions.onediff.sidebar")

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
  
  vim.cmd("edit " .. vim.fn.fnameescape(file.full_path))
  local buf = vim.api.nvim_get_current_buf()
  session.set_diff_buf(buf)

  M.setup_buffer_keymaps(buf)
  M.clear_buffer_highlights(buf)
  
  if file.status == "untracked" then
    M.highlight_untracked_file(buf)
  else
    M.apply_inline_diff(buf, hunks, file, base_ref)
  end
  
  local first_change_line = nil
  if hunks and #hunks > 0 then
    local diff_parse = require("my_extensions.onediff.diff_parse")
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

function M.setup_buffer_keymaps(buf)
  local onediff = require("my_extensions.onediff")
  local opts = { buffer = buf, silent = true, nowait = true }

  vim.keymap.set("n", "<Tab>", onediff.goto_next_change, opts)
  vim.keymap.set("n", "<S-Tab>", onediff.goto_prev_change, opts)
  vim.keymap.set("n", "<C-i>", onediff.goto_next_change, opts)
  vim.keymap.set("n", "<C-o>", onediff.goto_prev_change, opts)
end

function M.render_deleted_file(file, base_ref, target_win)
  local git_ops = require("my_extensions.onediff.git_ops")
  local settings = require("my_extensions.onediff.settings")
  local session = require("my_extensions.onediff.session")

  local content = git_ops.get_base_content(file.path, base_ref)
  if not content then
    vim.notify("OneDiff: Could not retrieve deleted file content", vim.log.levels.WARN)
    return
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(target_win, buf)
  session.set_diff_buf(buf)

  local lines = vim.split(content, "\n")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  vim.bo[buf].modifiable = false
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.api.nvim_buf_set_name(buf, "[deleted] " .. file.path)

  local ext = file.path:match("%.(%w+)$")
  if ext then
    local ft = vim.filetype.match({ filename = file.path })
    if ft then
      vim.bo[buf].filetype = ft
    end
  end

  local ns = settings.get_ns()
  local hl = settings.get("highlights")
  for i = 0, #lines - 1 do
    vim.api.nvim_buf_set_extmark(buf, ns, i, 0, {
      line_hl_group = hl.line_delete,
    })
  end

  M.setup_buffer_keymaps(buf)
end

function M.apply_inline_diff(buf, hunks, file, base_ref)
  local settings = require("my_extensions.onediff.settings")

  if not hunks or #hunks == 0 then
    return
  end

  local ns = settings.get_ns()
  local hl = settings.get("highlights")
  local buf_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local buf_line_count = #buf_lines

  for _, hunk in ipairs(hunks) do
    local new_line_idx = hunk.new_start - 1
    local deleted_lines = {}
    local deleted_attach_line = nil

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
            line_hl_group = hl.line_add,
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
end

function M.highlight_untracked_file(buf)
  local settings = require("my_extensions.onediff.settings")
  local ns = settings.get_ns()
  local hl = settings.get("highlights")
  
  local line_count = vim.api.nvim_buf_line_count(buf)
  for i = 0, line_count - 1 do
    vim.api.nvim_buf_set_extmark(buf, ns, i, 0, {
      line_hl_group = hl.line_add,
    })
  end
end

function M.clear_buffer_highlights(buf)
  local settings = require("my_extensions.onediff.settings")
  local ns = settings.get_ns()
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
end

function M.clear_all()
  local session = require("my_extensions.onediff.session")
  local settings = require("my_extensions.onediff.settings")

  local diff_buf = session.get_diff_buf()
  if diff_buf and vim.api.nvim_buf_is_valid(diff_buf) then
    M.clear_buffer_highlights(diff_buf)
  end
end

return M
