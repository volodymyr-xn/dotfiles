local M = {}

function M.next_file()
  local session = require("my_extensions.onediff.session")
  local display = require("my_extensions.onediff.display")
  local sidebar = require("my_extensions.onediff.sidebar")

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
  local session = require("my_extensions.onediff.session")
  local display = require("my_extensions.onediff.display")
  local sidebar = require("my_extensions.onediff.sidebar")

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

function M.next_change()
  local session = require("my_extensions.onediff.session")
  local diff_parse = require("my_extensions.onediff.diff_parse")
  local display = require("my_extensions.onediff.display")
  local sidebar = require("my_extensions.onediff.sidebar")

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
      vim.api.nvim_win_set_cursor(0, { block.start, 0 })
      vim.cmd("normal! zz")
      return
    elseif current_line >= block.start and current_line <= block.finish then
      -- Inside a block, find the next one
      for _, next_block in ipairs(change_blocks) do
        if next_block.start > block.finish then
          vim.api.nvim_win_set_cursor(0, { next_block.start, 0 })
          vim.cmd("normal! zz")
          return
        end
      end
      break
    end
  end

  local count = session.get_file_count()
  if count <= 1 then
    if #change_blocks > 0 then
      vim.api.nvim_win_set_cursor(0, { change_blocks[1].start, 0 })
      vim.cmd("normal! zz")
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

  vim.defer_fn(function()
    local new_hunks = session.get_hunks()
    if new_hunks and #new_hunks > 0 then
      local new_blocks = diff_parse.get_change_lines_in_buffer(new_hunks)
      if #new_blocks > 0 then
        vim.api.nvim_win_set_cursor(0, { new_blocks[1].start, 0 })
        vim.cmd("normal! zz")
      end
    end
  end, 10)
end

function M.prev_change()
  local session = require("my_extensions.onediff.session")
  local diff_parse = require("my_extensions.onediff.diff_parse")
  local display = require("my_extensions.onediff.display")
  local sidebar = require("my_extensions.onediff.sidebar")

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
      vim.api.nvim_win_set_cursor(0, { block.start, 0 })
      vim.cmd("normal! zz")
      return
    elseif current_line >= block.start and current_line <= block.finish then
      -- Inside a block, find the previous one
      for j = i - 1, 1, -1 do
        vim.api.nvim_win_set_cursor(0, { change_blocks[j].start, 0 })
        vim.cmd("normal! zz")
        return
      end
      break
    end
  end

  local count = session.get_file_count()
  if count <= 1 then
    if #change_blocks > 0 then
      vim.api.nvim_win_set_cursor(0, { change_blocks[#change_blocks].start, 0 })
      vim.cmd("normal! zz")
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

  vim.defer_fn(function()
    local new_hunks = session.get_hunks()
    if new_hunks and #new_hunks > 0 then
      local new_blocks = diff_parse.get_change_lines_in_buffer(new_hunks)
      if #new_blocks > 0 then
        vim.api.nvim_win_set_cursor(0, { new_blocks[#new_blocks].start, 0 })
        vim.cmd("normal! zz")
      end
    end
  end, 10)
end

function M.goto_hunk(hunk_index)
  local session = require("my_extensions.onediff.session")

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
    vim.api.nvim_win_set_cursor(0, { hunk.new_start, 0 })
    vim.cmd("normal! zz")
  end
end

function M.get_current_hunk_index()
  local session = require("my_extensions.onediff.session")

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
