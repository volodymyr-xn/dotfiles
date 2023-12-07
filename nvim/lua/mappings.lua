--============================================================================
--====================== Mapings =============================================
--============================================================================
-- Remap VIM 0 to first non-blank character
vim.api.nvim_set_keymap('n', '0', '^', { noremap = true })

-- Pressing will toggle and untoggle spell checking
-- vim.api.nvim_set_keymap('n', '<Leader>custom', ':setlocal spell!<cr>', { noremap = true })

-- Save current file
vim.api.nvim_set_keymap('n', '<Leader>w', ':w<CR>', { silent = true, noremap = true })

-- Go to the begining of line
vim.api.nvim_set_keymap('n', 'H', '^', { noremap = true })

-- Go to the end of line
vim.api.nvim_set_keymap('n', 'L', '$', { noremap = true })

-- Run 'git blame' on a selection of code
vim.api.nvim_set_keymap('n', '<Leader>gb', ':Git blame<CR>', { noremap = true })

-- Run 'git status' for current file
-- vim.api.nvim_set_keymap('n', '<Leader>gs', ':Gstatus<CR>', { noremap = true })

-- Change surround single quotes to double quotes
-- vim.api.nvim_set_keymap('n', '<Leader>8', 'cs\'"', { noremap = true })

-- Quit
vim.api.nvim_set_keymap('n', 'Q', '<C-W>q', { noremap = true })

-- Faster search
-- vim.api.nvim_set_keymap('n', 's', '/', { noremap = true })

-- Fix indenting selection
vim.api.nvim_set_keymap('v', '<', '<gv', { noremap = true })
vim.api.nvim_set_keymap('v', '>', '>gv', { noremap = true })

-- Open a new tab with Ctrl+T
-- vim.api.nvim_set_keymap('n', '<C-t>', '<esc>:tabnew<CR>', { silent = true, noremap = true })
-- vim.api.nvim_set_keymap('n', 'T', '<esc>:tabnew<CR>', { silent = true, noremap = true })
vim.api.nvim_set_keymap('n', '<c-t>', '<esc>:tabnew<CR>', { silent = true, noremap = true })

-- Disable selection
vim.api.nvim_set_keymap('n', '<Leader>n', ':nohl<CR>', { silent = true, noremap = true })

-- Enter replace command
-- Global search and replace in quickfix menu
vim.api.nvim_set_keymap('n', '@', ':%s///g<Left><Left><Left><Left>', { noremap = true })
-- vim.api.nvim_set_keymap('n', 's', ':w<CR>', { noremap = true })
vim.api.nvim_set_keymap('n', '<Leader>r', ":cfdo %s///g | update <c-b><right><right><right><right><right><right><right><right>", { noremap = true })

-- Edit vim config
vim.api.nvim_set_keymap('n', '<Leader>ve', ':e ~/.config/nvim/init.lua<cr>', { noremap = true })

-- Reload vim config
vim.api.nvim_set_keymap('n', '<Leader>vr', ':luafile %<CR>', { noremap = true })

-- Reload chrome tab
-- vim.api.nvim_set_keymap('n', 'R', ':lua ReloadActiveChromeTab()<CR>', { noremap = true })

-- Move up and down by visible lines if current line is wrapped
vim.api.nvim_set_keymap('n', 'j', 'gj', { noremap = true })
vim.api.nvim_set_keymap('n', 'k', 'gk', { noremap = true })
vim.api.nvim_set_keymap('n', 'K', 'k', { noremap = true })

vim.api.nvim_set_keymap('n', 'e', 'E', { noremap = true })

-- Easily navigate between tabs
-- vim.api.nvim_set_keymap('n', 'E', ':tabprev<CR>', { noremap = true })
-- Tab nad <C-I> in terminal returns the same code
vim.api.nvim_set_keymap('n', 'R', ':tabnext<CR>', { noremap = true })
-- Switch between tabs
vim.api.nvim_set_keymap('n', '<C-q>', ':tabprev<CR>', {noremap = true})
vim.api.nvim_set_keymap('n', '<C-e>', ':tabnext<CR>', {noremap = true})
-- Tabs
-- vim.api.nvim_set_keymap('n', '<C-Left>', ':tabprev<CR>', {noremap = true})
-- vim.api.nvim_set_keymap('n', '<C-Right>', ':tabnext<CR>', {noremap = true})
-- vim.api.nvim_set_keymap('n', 'q', ':tabnext<CR>', {noremap = true})

-- Buffer select
vim.api.nvim_set_keymap('n', 'q', ':Telescope buffers<CR>', {noremap = true})

-- Copy selected text to system clipboard
vim.api.nvim_set_keymap('v', 'm', '"+y', { noremap = true })

-- Copy current line to system clipboard
vim.api.nvim_set_keymap('n', '`', '"+yy', { noremap = true })

-- Copy relative path of the current file to the clipboard
vim.api.nvim_set_keymap('n', '`', ':let @+ = expand("%")<CR>', { noremap = true, silent = true })

-- Easily resize windows
vim.api.nvim_set_keymap('n', '<', '<C-w>5<', { noremap = true })
vim.api.nvim_set_keymap('n', '>', '<C-w>5>', { noremap = true })
vim.api.nvim_set_keymap('n', '+', '<C-w>5+', { noremap = true })
vim.api.nvim_set_keymap('n', '_', '<C-w>5-', { noremap = true })

-- Move current line up
vim.api.nvim_set_keymap('n', '<S-Up>', ':m .-2<CR>==', { noremap = true })
vim.api.nvim_set_keymap('i', '<S-Up>', '<ESC>:m .-2<CR>==gi', { noremap = true })

-- Move current line down
vim.api.nvim_set_keymap('n', '<S-Down>', ':m .+1<CR>==', { noremap = true })
vim.api.nvim_set_keymap('i', '<S-Down>', '<ESC>:m .+1<CR>==gi', { noremap = true })

-- Move multiple lines up in visual mode
vim.api.nvim_set_keymap('x', 'K', ':m \'<-2<CR>gv=gv', { noremap = true })

-- Toggle folding
vim.api.nvim_set_keymap('n', 'K', 'za', {noremap = true})
vim.api.nvim_set_keymap('x', '<2-LeftMouse>', 'za', {noremap = true})

-- vim.api.nvim_set_keymap('n', '<A-k>', ':tabprev<CR>', {noremap = true})
-- vim.api.nvim_set_keymap('n', '<A-j>', ':tabnext<CR>', {noremap = true})
-- vim.api.nvim_set_keymap('n', '<A-e>', ':tabprev<CR>', {noremap = true})
-- vim.api.nvim_set_keymap('n', '<A-w>', ':tabnext<CR>', {noremap = true})

-- Map text align to tab button in visual mode
vim.api.nvim_set_keymap('v', '<TAB>', '=', {noremap = true})

-- Expand window
vim.api.nvim_set_keymap('n', '"', '<C-W>|<C-W>_', {noremap = true})

-- Re-balance panes
vim.api.nvim_set_keymap('n', '=', '<C-W>=', {noremap = true})

-- Toggle current window zoom
vim.api.nvim_set_keymap('n', 'm', ':ToggleCurrentWindowZoom<CR>', {noremap = true})

-- Select tab by number
-- 'ctrl-m 1' - selects first tab, etc
for i=1,9 do
  vim.api.nvim_set_keymap('n', '<C-w>'..i, i..'gt<CR>', {noremap = true})
end

-- Select tab by number
-- 'Leader 1' - selects first tab, etc
for i=1,9 do
  vim.api.nvim_set_keymap('n', '<Leader>'..i, i..'gt<CR>', {noremap = true})
end

vim.api.nvim_set_keymap('v', 'M', "yV\'] :TComment<CR>\']jp", {noremap = true})
-- vim.api.nvim_set_keymap('n', 'M', 'yy\']:TComment<CR>\']pjj', {noremap = true})

-- Faster close windows and quit
vim.api.nvim_set_keymap('n', '<C-c>', '<C-w>q', {noremap = true})

-- Test runner mappings
vim.api.nvim_set_keymap('n', '<Leader>t', ':TestNearest<CR>', {silent = true})
vim.api.nvim_set_keymap('n', '<Leader>T', ':TestFile<CR>', {silent = true})
vim.api.nvim_set_keymap('n', '<Leader>a', ':TestSuite<CR>', {silent = true})
vim.api.nvim_set_keymap('n', '<Leader>l', ':TestLast<CR>', {silent = true})

-- Go to related file
vim.api.nvim_set_keymap('n', '<Leader>e', ':R<CR>', { noremap = true })

-- Go to alternate file
-- vim.api.nvim_set_keymap('n', 'q', ':A<CR>', { noremap = true })

-- Auto indent pasted text
vim.api.nvim_set_keymap('n', 'p', 'p=`]<C-o>', { noremap = true })
vim.api.nvim_set_keymap('n', 'P', 'P=`]<C-o>', { noremap = true })

-- Move to the end of yanked text after yank and paste
vim.api.nvim_set_keymap('n', 'p', 'p`]', { noremap = true })
vim.api.nvim_set_keymap('v', 'y', 'y`]', { noremap = true })
vim.api.nvim_set_keymap('v', 'p', 'p`]', { noremap = true })

-- Fixes pasting after visual selection.
vim.api.nvim_set_keymap('x', 'p', '"_dP', { noremap = true })

-- Switch to last file
-- vim.api.nvim_set_keymap('n', 'R', '<c-^>', { noremap = true })

-- Tcomment
-- Comment line in visual mode
vim.api.nvim_set_keymap('v', '\\', ':TComment<CR>', { noremap = true })

-- Comment line in normal mode
vim.api.nvim_set_keymap('n', '\\', ':TComment<CR>', { noremap = true })


-- vim.api.nvim_set_keymap('n', '<leader>-', ':vsplit<CR>', { noremap = true })
-- vim.api.nvim_set_keymap('n', 'M', ':vsplit<CR>', { noremap = true })
vim.api.nvim_set_keymap('n', 'M', ':tabnext<CR>', { noremap = true })

-- SUPER EXPERIMENTAL
function switch_to_next_file()
  -- Get the current buffer's file name
  local file_name = vim.fn.expand('%:p')

  -- Get the directory of the current buffer's file name
  local file_dir = vim.fn.fnamemodify(file_name, ':h')

  -- Get a list of files in the directory, sorted by name
  local file_list = vim.fn.systemlist('ls -1 "'..file_dir..'"')

  -- Find the index of the current file name in the list
  local current_index = vim.fn.index(file_list, vim.fn.fnamemodify(file_name, ':t'))

  -- Find the index of the next file name in the list
  local next_index = (current_index % #file_list) + 1

  -- Get the next file name in the list
  local next_file = file_list[next_index + 1]

  print("next_file: " .. next_file)
  -- Open the next file
  vim.cmd('edit '..file_dir..'/'..next_file)
end

-- Map <leader>n to switch to the next file in the directory
-- vim.api.nvim_set_keymap('n', '<leader>b', ':lua switch_to_next_file()<CR>', { noremap = true })

-- Change surround double quotes to plain quotes
-- vim.api.nvim_set_keymap('n', '<Leader>b', 'cs\'"', { noremap = true })
vim.api.nvim_set_keymap('n', '-', 'cs\'\"', {})
