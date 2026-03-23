local M = {}

function M.next_file()
  local session = require("my_plugins.onediff.session")
  local display = require("my_plugins.onediff.display")
  local sidebar = require("my_plugins.onediff.sidebar")

  if not session.is_open() then
    vim.notify("OneDiff: Not active", vim.log.levels.WARN)
    return
  end

  local count = session.get_file_count()
  if count == 0 then
    vim.notify("OneDiff: No files to navigate", vim.log.levels.INFO)
    return
  end

  local current = session.get_current_index()
  local next_idx = current + 1
  if next_idx > count then
    next_idx = 1
  end

  session.set_current_index(next_idx)
  sidebar.render()
  display.render_current()
end

function M.prev_file()
  local session = require("my_plugins.onediff.session")
  local display = require("my_plugins.onediff.display")
  local sidebar = require("my_plugins.onediff.sidebar")

  if not session.is_open() then
    vim.notify("OneDiff: Not active", vim.log.levels.WARN)
    return
  end

  local count = session.get_file_count()
  if count == 0 then
    vim.notify("OneDiff: No files to navigate", vim.log.levels.INFO)
    return
  end

  local current = session.get_current_index()
  local prev_idx = current - 1
  if prev_idx < 1 then
    prev_idx = count
  end

  session.set_current_index(prev_idx)
  sidebar.render()
  display.render_current()
end

local function safe_set_cursor(line)
  local buf = vim.api.nvim_get_current_buf()
  local line_count = vim.api.nvim_buf_line_count(buf)
  if line >= 1 and line <= line_count then
    vim.api.nvim_win_set_cursor(0, { line, 0 })
    vim.cmd("normal! zz")
    return true
  end
  return false
end

function M.next_change()
  local session = require("my_plugins.onediff.session")
  local diff_parse = require("my_plugins.onediff.diff_parse")
  local display = require("my_plugins.onediff.display")
  local sidebar = require("my_plugins.onediff.sidebar")

  if not session.is_open() then
    vim.notify("OneDiff: Not active", vim.log.levels.WARN)
    return
  end

  local hunks = session.get_hunks()
  local change_blocks = {}
  if hunks and #hunks > 0 then
    change_blocks = diff_parse.get_change_lines_in_buffer(hunks)
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local current_line = cursor[1]

  for _, block in ipairs(change_blocks) do
    if block.start > current_line then
      if safe_set_cursor(block.start) then
        return
      end
    elseif current_line >= block.start and current_line <= block.finish then
      for _, next_block in ipairs(change_blocks) do
        if next_block.start > block.finish then
          if safe_set_cursor(next_block.start) then
            return
          end
        end
      end
      break
    end
  end

  local count = session.get_file_count()
  if count <= 1 then
    if #change_blocks > 0 then
      safe_set_cursor(change_blocks[1].start)
    end
    return
  end

  local current_idx = session.get_current_index()
  local next_idx = current_idx + 1
  if next_idx > count then
    next_idx = 1
  end

  session.set_current_index(next_idx)
  sidebar.render()
  display.render_current()
end

function M.prev_change()
  local session = require("my_plugins.onediff.session")
  local diff_parse = require("my_plugins.onediff.diff_parse")
  local display = require("my_plugins.onediff.display")
  local sidebar = require("my_plugins.onediff.sidebar")

  if not session.is_open() then
    vim.notify("OneDiff: Not active", vim.log.levels.WARN)
    return
  end

  local hunks = session.get_hunks()
  local change_blocks = {}
  if hunks and #hunks > 0 then
    change_blocks = diff_parse.get_change_lines_in_buffer(hunks)
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local current_line = cursor[1]

  for i = #change_blocks, 1, -1 do
    local block = change_blocks[i]
    if block.finish < current_line then
      if safe_set_cursor(block.start) then
        return
      end
    elseif current_line >= block.start and current_line <= block.finish then
      for j = i - 1, 1, -1 do
        if safe_set_cursor(change_blocks[j].start) then
          return
        end
      end
      break
    end
  end

  local count = session.get_file_count()
  if count <= 1 then
    if #change_blocks > 0 then
      safe_set_cursor(change_blocks[#change_blocks].start)
    end
    return
  end

  local current_idx = session.get_current_index()
  local prev_idx = current_idx - 1
  if prev_idx < 1 then
    prev_idx = count
  end

  session.set_current_index(prev_idx)
  sidebar.render()
  display.render_current()
end

function M.goto_hunk(hunk_index)
  local session = require("my_plugins.onediff.session")

  if not session.is_open() then
    return
  end

  local hunks = session.get_hunks()
  if not hunks or #hunks == 0 then
    return
  end

  local idx = hunk_index
  if idx < 1 then
    idx = #hunks
  elseif idx > #hunks then
    idx = 1
  end

  local hunk = hunks[idx]
  if hunk then
    safe_set_cursor(hunk.new_start)
  end
end

function M.get_current_hunk_index()
  local session = require("my_plugins.onediff.session")

  local hunks = session.get_hunks()
  if not hunks or #hunks == 0 then
    return 0
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local current_line = cursor[1]

  for i, hunk in ipairs(hunks) do
    local hunk_end = hunk.new_start + hunk.new_count - 1
    if current_line >= hunk.new_start and current_line <= hunk_end then
      return i
    end
  end

  for i = #hunks, 1, -1 do
    if current_line >= hunks[i].new_start then
      return i
    end
  end

  return 0
end

return M
