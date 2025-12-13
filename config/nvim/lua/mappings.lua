--============================================================================
--====================== Mapings =============================================
--============================================================================
-- Remap VIM 0 to first non-blank character
-- vim.api.nvim_set_keymap('n', '0', '^', { noremap = true })

-- Pressing will toggle and untoggle spell checking
-- vim.api.nvim_set_keymap('n', '<Leader>custom', ':setlocal spell!<cr>', { noremap = true })

-- Save current file
vim.api.nvim_set_keymap('n', '<Leader>w', ':w<CR>', { silent = true, noremap = true, desc = "Save current file" })

-- Go to the begining of line
vim.api.nvim_set_keymap('n', 'H', '^', { noremap = true, desc = "Go to beginning of line" })

-- Go to the end of line
vim.api.nvim_set_keymap('n', 'L', '$', { noremap = true, desc = "Go to end of line" })

-- Select word under cursor
vim.api.nvim_set_keymap('n', '*', 'viwy', { silent = true, noremap = true, desc = "Select word under cursor" })

-- Run 'git blame' on a selection of code
vim.api.nvim_set_keymap('n', '<Leader>gb', ':Git blame<CR>', { noremap = true, desc = "Git blame" })

-- Run 'git status' for current file
-- vim.api.nvim_set_keymap('n', '<Leader>gs', ':Gstatus<CR>', { noremap = true })

-- Change surround single quotes to double quotes
-- vim.api.nvim_set_keymap('n', '<Leader>8', 'cs\'"', { noremap = true })

-- Quit
-- vim.api.nvim_set_keymap('n', 'Q', '<C-W>q', { noremap = true })
-- Go to alternate file
vim.api.nvim_set_keymap('n', 'Q', ':A<CR>', { noremap = true, desc = "Go to alternate file" })

-- Faster search
-- vim.api.nvim_set_keymap('n', 's', '/', { noremap = true })

-- Fix indenting selection
vim.api.nvim_set_keymap('v', '<', '<gv', { noremap = true, desc = "Indent left and reselect" })
vim.api.nvim_set_keymap('v', '>', '>gv', { noremap = true, desc = "Indent right and reselect" })

-- Open a new tab with Ctrl+T
-- vim.api.nvim_set_keymap('n', '<C-t>', '<esc>:tabnew<CR>', { silent = true, noremap = true })
-- vim.api.nvim_set_keymap('n', 'T', '<esc>:tabnew<CR>', { silent = true, noremap = true })
vim.api.nvim_set_keymap('n', '<c-t>', '<esc>:tabnew<CR>', { silent = true, noremap = true, desc = "Open new tab" })

-- Disable selection
vim.api.nvim_set_keymap('n', '<Leader>n', ':nohl<CR>', { silent = true, noremap = true, desc = "Clear search highlight" })

-- Enter replace command
-- Global search and replace in file
vim.api.nvim_set_keymap('n', 'sr', ':%s///g<Left><Left><Left>', { noremap = true, desc = "Search and replace in file" })
-- vim.api.nvim_set_keymap('n', 's', ':w<CR>', { noremap = true })
-- Global search and replace in quickfix menu
vim.api.nvim_set_keymap('n', '@', ":cfdo %s///g | update <c-b><right><right><right><right><right><right><right><right>", { noremap = true, desc = "Search and replace in quickfix" })
-- vim.api.nvim_set_keymap('n', '<Leader>r', ":cdfo %s///g | update <c-b><right><right><right><right><right><right><right><right>", { noremap = true })

-- Edit vim config
vim.api.nvim_set_keymap('n', '<Leader>ve', ':e ~/.config/nvim/init.lua<cr>', { noremap = true, desc = "Edit vim config" })

-- Reload vim config
vim.api.nvim_set_keymap('n', '<Leader>vr', ':luafile %<CR>', { noremap = true, desc = "Reload vim config" })

-- Reload chrome tab
-- vim.api.nvim_set_keymap('n', 'R', ':lua ReloadActiveChromeTab()<CR>', { noremap = true })

-- Move up and down by visible lines if current line is wrapped
vim.api.nvim_set_keymap('n', 'j', 'gj', { noremap = true, desc = "Move down by visual line" })
vim.api.nvim_set_keymap('n', 'k', 'gk', { noremap = true, desc = "Move up by visual line" })
-- vim.api.nvim_set_keymap('n', 'K', 'k', { noremap = true })

-- Move to end of WORD
vim.api.nvim_set_keymap('n', 'e', 'E', { noremap = true, desc = "Move to end of WORD" })

-- Easily navigate between tabs
-- vim.api.nvim_set_keymap('n', 'E', ':tabprev<CR>', { noremap = true })
-- Tab nad <C-I> in terminal returns the same code
-- Tabs
vim.api.nvim_set_keymap('n', '<C-Left>', ':tabprev<CR>', {noremap = true, desc = "Previous tab"})
vim.api.nvim_set_keymap('n', '<C-Right>', ':tabnext<CR>', {noremap = true, desc = "Next tab"})

-- Copy selected text to system clipboard
vim.api.nvim_set_keymap('v', 'm', '"+y', { noremap = true, desc = "Copy to system clipboard" })

-- Copy current line to system clipboard
-- vim.api.nvim_set_keymap('n', '`', '"+yy', { noremap = true })

-- Easily resize windows
vim.api.nvim_set_keymap('n', '<', '<C-w>5<', { noremap = true, desc = "Decrease window width" })
vim.api.nvim_set_keymap('n', '>', '<C-w>5>', { noremap = true, desc = "Increase window width" })
vim.api.nvim_set_keymap('n', '+', '<C-w>5+', { noremap = true, desc = "Increase window height" })
vim.api.nvim_set_keymap('n', '_', '<C-w>5-', { noremap = true, desc = "Decrease window height" })

-- Move multiple lines in visual mode
vim.api.nvim_set_keymap('v', 'K', ":m '<-2<CR>gv=gv", { noremap = true, desc = "Move lines up" })
vim.api.nvim_set_keymap('v', 'J', ":m '>+1<CR>gv=gv", { noremap = true, desc = "Move lines down" })
-- vim.api.nvim_set_keymap('v', 'J', ':m .+1<CR>==', { noremap = true })
-- vim.api.nvim_set_keymap('v', 'J', '<ESC>:m .+1<CR>==gi', { noremap = true })

-- Move current line up
-- vim.api.nvim_set_keymap('v', 'J', ':m .-2<CR>==', { noremap = true })
-- vim.api.nvim_set_keymap('i', '<S-Up>', '<ESC>:m .-2<CR>==gi', { noremap = true })

-- Move current line down
-- vim.api.nvim_set_keymap('n', '<S-Down>', ':m .+1<CR>==', { noremap = true })

-- Move multiple lines up in visual mode
-- vim.api.nvim_set_keymap('x', 'K', ':m \'<-2<CR>gv=gv', { noremap = true })

-- Toggle folding
-- vim.api.nvim_set_keymap('n', 'N', 'za', {noremap = true})
vim.api.nvim_set_keymap('n', '0', 'za', {noremap = true, desc = "Toggle fold"})
-- vim.api.nvim_set_keymap('x', '<2-LeftMouse>', 'za', {noremap = true})

-- Map text align to tab button in visual mode
vim.api.nvim_set_keymap('v', '<Tab>', '=', {noremap = true, desc = "Auto-indent selection"})
-- vim.api.nvim_set_keymap('v', '<Leader><Tab>', '=', {noremap = true})

-- Expand window
vim.api.nvim_set_keymap('n', '"', '<C-W>|<C-W>_', {noremap = true, desc = "Maximize window"})

-- Re-balance panes
vim.api.nvim_set_keymap('n', '=', '<C-W>=', {noremap = true, desc = "Balance windows"})

-- Toggle current window zoom
vim.api.nvim_set_keymap('n', 'm', ':ToggleCurrentWindowZoom<CR>', { noremap = true, silent = true, desc = "Toggle window zoom" })

-- Select tab by number
-- 'ctrl-m 1' - selects first tab, etc
for i=1,9 do
  vim.api.nvim_set_keymap('n', '<C-w>'..i, i..'gt<CR>', {noremap = true, desc = "Go to tab " .. i})
end

-- Select tab by number
-- 'Leader 1' - selects first tab, etc
for i=1,9 do
  vim.api.nvim_set_keymap('n', '<Leader>'..i, i..'gt<CR>', {noremap = true, desc = "Go to tab " .. i})
end

-- vim.api.nvim_set_keymap('v', 'M', "yV\'] :TComment<CR>\']jp", {noremap = true})
-- vim.api.nvim_set_keymap('n', 'M', 'yy\']:TComment<CR>\']pjj', {noremap = true})

-- Faster close windows and quit
vim.api.nvim_set_keymap('n', '<C-c>', '<C-w>q', {noremap = true, desc = "Close window"})

-- Test runner mappings
vim.api.nvim_set_keymap('n', '<Leader>t', ':TestNearest<CR>', {silent = true, desc = "Test nearest"})
vim.api.nvim_set_keymap('n', '<Leader>T', ':TestFile<CR>', {silent = true, desc = "Test file"})
-- vim.api.nvim_set_keymap('n', '<Leader>a', ':TestSuite<CR>', {silent = true})
vim.api.nvim_set_keymap('n', '<Leader>l', ':TestLast<CR>', {silent = true, desc = "Test last"})

-- Go to related file
vim.api.nvim_set_keymap('n', '<Leader>a', ':R<CR>', { noremap = true, desc = "Go to related file" })
vim.api.nvim_set_keymap('n', 'gs', ':R<CR>', { noremap = true, desc = "Go to related file" })
vim.api.nvim_set_keymap('n', 'ga', ':A<CR>', { noremap = true, desc = "Go to related file" })

-- Reload file
vim.api.nvim_set_keymap('n', '<Leader>e', ':e!<CR>', { noremap = true, silent = true, desc = "Reload file" })
-- vim.api.nvim_set_keymap('n', '<Leader>r', ':e!<CR>', { noremap = true, silent = true, desc = "Reload file" })

-- Go to alternate file
-- vim.api.nvim_set_keymap('n', 'q', ':A<CR>', { noremap = true })

-- Auto indent pasted text
-- vim.api.nvim_set_keymap('n', 'p', 'p=`]<C-o>', { noremap = true })
-- vim.api.nvim_set_keymap('n', 'P', 'P=`]<C-o>', { noremap = true })

-- Move to the end of yanked text after yank and paste
vim.api.nvim_set_keymap('n', 'p', 'p`]', { noremap = true, desc = "Paste and move to end" })
vim.api.nvim_set_keymap('v', 'y', 'y`]', { noremap = true, desc = "Yank and move to end" })
vim.api.nvim_set_keymap('v', 'p', 'p`]', { noremap = true, desc = "Paste and move to end" })

-- Fixes pasting after visual selection.
vim.api.nvim_set_keymap('x', 'p', '"_dP', { noremap = true, desc = "Paste without yanking" })

-- Switch to last file
-- vim.api.nvim_set_keymap('n', 'R', '<c-^>', { noremap = true })


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
-- Change single quotes to double quotes
vim.api.nvim_set_keymap('n', '-', 'cs\'\"', { desc = "Change single to double quotes" })


