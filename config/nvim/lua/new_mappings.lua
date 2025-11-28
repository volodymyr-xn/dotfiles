-- Copy relative path of the current file to the clipboard
-- vim.api.nvim_set_keymap('n', '`', ':let @+ = expand("%")<CR>', { noremap = true, silent = true })
-- vim.api.nvim_set_keymap('n', '`', ':let @+ = @%<CR>', { noremap = true, silent = true })

-- Switch between tabs
-- vim.api.nvim_set_keymap('n', '<C-q>', ':tabprev<CR>', {noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<C-e>', ':tabnext<CR>', {noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<M-k>', ':tabprev<CR>', {noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<M-j>', ':tabnext<CR>', {noremap = true, silent = true })

-- Split window vertically by presing shift + M
vim.api.nvim_set_keymap('n', 'M', ':vsplit<CR>', { noremap = true, silent = true })
-- Go to the beginning of the line
vim.api.nvim_set_keymap('v', 'H', '^', {noremap = true, silent = true })
-- Go to the end of the line
vim.api.nvim_set_keymap('v', 'L', '$', {noremap = true, silent = true })

-- vim.api.nvim_set_keymap('n', '<C-3>', '#', {noremap = true, silent = true })


-- vim.api.nvim_set_keymap('n', '`', ':let @+ = expand("%")<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '`', ':CopyCurrentFileRelativePathToClipboard<CR>', { noremap = true })
-- vim.api.nvim_set_keymap('n', '~', ':CopyCurrentFileNameToClipboard<CR>', { noremap = true })

vim.api.nvim_set_keymap('n', '<Leader>!', ':Ack "binding.pry"<CR>', {noremap = true, silent = false })

-- vim.api.nvim_set_keymap('n', '<C-s>', '<C-w>v', {noremap = true, silent = false })

-- Free mappings for "s" button that works as prefix
vim.api.nvim_set_keymap('n', 's', '', {noremap = true, silent = false })
vim.api.nvim_set_keymap('n', 'st', '<C-w>s', {noremap = true, silent = false })

-- vim.api.nvim_set_keymap('n', '<Leader>h', ':Telescope jumplist<CR>', {noremap = true, silent = false })
-- vim.api.nvim_set_keymap('n', '<Leader>q', ':Telescope buffers<CR>', {noremap = true, silent = false })
vim.api.nvim_set_keymap('n', '<Leader>h', ':Telescope buffers<CR>', {noremap = true, silent = false })

vim.api.nvim_set_keymap('n', 'ss', ':R<CR>', {noremap = true, silent = false })

-- vim.api.nvim_set_keymap('n', 'dn', 'bdiw', {})

-- Quick binding.pry
-- vim.cmd [[
--  nnoremap <leader>q o<Esc>==i binding.pry<Esc>==o<Esc>kko<Esc>j
-- ]]

-- Define a function to insert the appropriate debug snippet
local function custom_insert_debug()
  local ft = vim.bo.filetype
  local snippet = ""

  if ft == "ruby" then
    snippet = "binding.pry"
  elseif ft == "eruby" then -- html.erb is usually detected as 'eruby'
    snippet = "<% binding.pry %>"
  elseif ft == "javascript" then
    snippet = "console.log()"
  elseif ft == "typescript" then -- optional, for TS
    snippet = "console.log()"
  else
    print("No debug snippet defined for filetype: " .. ft)
    return
  end

  -- Insert snippet in new line below current cursor
  vim.api.nvim_feedkeys("o" .. snippet .. vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)

  -- Move cursor inside parentheses if console.log()
  if snippet == "console.log()" then
    vim.api.nvim_feedkeys("F(a", "n", false)
  end
end

local function highlight_word_under_cursor()
  local word = vim.fn.expand("<cword>")
  local pattern = "\\<" .. word .. "\\>"
  vim.fn.setreg("/", pattern)
end

-- Insert debug
-- vim.keymap.set("n", "<Leader>q", custom_insert_debug, { noremap = true, silent = true })
vim.keymap.set("n", "<Leader>`", custom_insert_debug, { noremap = true, silent = true })

-- vim.keymap.set("n", "sa", ":A<CR>", { noremap = true, silent = true })
-- vim.keymap.set('n', 's', ':tabnext<CR>', { noremap = true })

-- vim.keymap.set('n', '@', highlight_word_under_cursor, { noremap = true, silent = true })
vim.keymap.set('n', '#', "*N", { noremap = true, silent = true })


-- vim.keymap.set('n', 'K', ':OutlineFocus<CR>', { noremap = true, silent = true })
-- vim.keymap.set('n', '<leader>k', ':Outline!<CR>', { noremap = true, silent = true })
vim.keymap.set('n', '<leader>k', ':TestFile<CR>', { noremap = true, silent = true })

-- Re-balance panes
-- vim.api.nvim_set_keymap('n', '=', '<C-W>=', {noremap = true})
--

