-- Standalone Git Diff Popup for Neovim
-- Add this directly to your init.lua

-- Function to create a centered floating window
local function create_float_window(buf, width_percent, height_percent)
  local width = math.floor(vim.o.columns * width_percent)
  local height = math.floor(vim.o.lines * height_percent)

  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local opts = {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    title = ' Git Diff ',
    title_pos = 'center',
  }

  local win = vim.api.nvim_open_win(buf, true, opts)

  return win
end

-- Function to show git diff in popup
local function show_git_diff(args)
  -- Get current file path
  local file = vim.fn.expand('%')

  if file == '' then
    vim.notify('No file in current buffer', vim.log.levels.WARN)
    return
  end

  -- Build git diff command for current file
  local cmd = 'git diff ' .. vim.fn.shellescape(file)

  -- Add arguments if provided (e.g., '--cached' for staged changes)
  if args and args ~= '' then
    cmd = 'git diff ' .. args .. ' ' .. vim.fn.shellescape(file)
  end

  local output = vim.fn.systemlist(cmd)

  -- Check if git command was successful
  if vim.v.shell_error ~= 0 then
    vim.notify('Git diff failed: ' .. table.concat(output, '\n'), vim.log.levels.ERROR)
    return
  end

  -- Check if there are any changes
  if #output == 0 then
    vim.notify('No changes found', vim.log.levels.INFO)
    return
  end

  -- Create a new buffer
  local buf = vim.api.nvim_create_buf(false, true)

  -- Set buffer options
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(buf, 'filetype', 'diff')
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)

  -- Set the diff output to buffer
  vim.api.nvim_buf_set_option(buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, output)
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)

  -- Create floating window (80% width, 80% height)
  local win = create_float_window(buf, 0.8, 0.8)

  -- Set window options
  vim.api.nvim_win_set_option(win, 'number', false)
  vim.api.nvim_win_set_option(win, 'relativenumber', false)
  vim.api.nvim_win_set_option(win, 'cursorline', true)

  -- Key mappings for the popup
  local keymaps = {
    ['q'] = '<cmd>close<cr>',
    ['<Esc>'] = '<cmd>close<cr>',
  }

  for key, cmd in pairs(keymaps) do
    vim.api.nvim_buf_set_keymap(buf, 'n', key, cmd, {
      nowait = true,
      noremap = true,
      silent = true
    })
  end
end

-- Create user command
vim.api.nvim_create_user_command('GitDiffPopup2', function(opts)
  show_git_diff(opts.args)
end, { nargs = '*' })


--[[ Usage:
  :GitDiff                - Show diff for current file
  :GitDiff --cached       - Show staged changes for current file
  :GitDiff HEAD~1         - Compare current file with previous commit
  :GitDiffStaged          - Show staged changes for current file
  <leader>gd              - Quick keymap

  Inside popup: q or <Esc> to close
]]
