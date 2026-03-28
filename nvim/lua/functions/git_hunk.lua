local gitsigns = require('gitsigns')

local hunk_flash_ns = vim.api.nvim_create_namespace('hunk_flash')
local hunk_flash_generation = 0

local function flash_current_hunk()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  local hunks = gitsigns.get_hunks(bufnr)

  if not hunks then return end

  hunk_flash_generation = hunk_flash_generation + 1
  local current_generation = hunk_flash_generation

  vim.api.nvim_buf_clear_namespace(bufnr, hunk_flash_ns, 0, -1)

  for _, hunk in ipairs(hunks) do
    local start = hunk.added.start
    local count = hunk.added.count

    if count > 0 and cursor_line >= start and cursor_line <= start + count - 1 then
      for lnum = start, start + count - 1 do
        vim.api.nvim_buf_add_highlight(bufnr, hunk_flash_ns, 'DiffAdd', lnum - 1, 0, -1)
      end

      vim.defer_fn(function()
        if hunk_flash_generation == current_generation then
          vim.api.nvim_buf_clear_namespace(bufnr, hunk_flash_ns, 0, -1)
        end
      end, 1000)

      return
    end
  end
end

function NavigateHunk(direction)
  gitsigns.nav_hunk(direction)

  vim.defer_fn(flash_current_hunk, 50)
end
