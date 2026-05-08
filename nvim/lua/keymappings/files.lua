local ruby_toggle = require('my_plugins.ruby_component_toggle')

-- Save current buffer
vim.api.nvim_set_keymap('n', '<Leader>w', ':w<CR>', { silent = true, noremap = true, desc = "Save current file" })

-- Re-source the entire Neovim config
vim.api.nvim_set_keymap('n', '<Leader>vr', ':source $MYVIMRC<CR>', { noremap = true, desc = "Reload vim config" })

-- Alternate/related file navigation (vim-projectionist)
vim.api.nvim_set_keymap('n', 'sa', ':A<CR>', { noremap = true, desc = "Go to alternate file" })
vim.api.nvim_set_keymap('n', 'sr', ':R<CR>', { noremap = true, desc = "Go to related file" })

-- Copy relative path of current file to system clipboard
vim.api.nvim_set_keymap('n', '`', ':CopyCurrentFileRelativePathToClipboard<CR>', { noremap = true, desc = "Copy file path to clipboard" })

-- Reload file from disk with a brief status echo
local function reload_file_with_message()
  vim.cmd('edit!')
  vim.api.nvim_echo({ { "File reloaded", "MoreMsg" } }, false, {})
  vim.defer_fn(function()
    vim.api.nvim_echo({ { "" } }, false, {})
  end, 1000)
end

-- Reload current file from disk (OneDiff buffers have their own buffer-local <Leader>e)
vim.keymap.set('n', '<Leader>e', reload_file_with_message, { noremap = true, silent = true, desc = "Reload file" })

-- Ruby ViewComponent: navigate to specific file type in the same component
vim.api.nvim_set_keymap('n', 's1', '<cmd>lua require("my_plugins.ruby_component_toggle").navigate_to_extension(".rb")<CR>',
  { noremap = true, silent = true, desc = "Navigate to .rb file" })
vim.api.nvim_set_keymap('n', 's2', '<cmd>lua require("my_plugins.ruby_component_toggle").navigate_to_extension(".html.erb")<CR>',
  { noremap = true, silent = true, desc = "Navigate to .html.erb file" })
vim.api.nvim_set_keymap('n', 's3', '<cmd>lua require("my_plugins.ruby_component_toggle").navigate_to_style()<CR>',
  { noremap = true, silent = true, desc = "Navigate to .scss/.css file" })
vim.api.nvim_set_keymap('n', 's4', '<cmd>lua require("my_plugins.ruby_component_toggle").navigate_to_extension(".js")<CR>',
  { noremap = true, silent = true, desc = "Navigate to .js file" })
vim.api.nvim_set_keymap('n', 'sq', '<cmd>lua require("my_plugins.ruby_component_toggle").toggle_js_erb()<CR>',
  { noremap = true, silent = true, desc = "Toggle between .js and .html.erb" })
vim.api.nvim_set_keymap('n', 'sw', '<cmd>lua require("my_plugins.ruby_component_toggle").toggle_erb_style()<CR>',
  { noremap = true, silent = true, desc = "Toggle between .html.erb and .scss/.css" })

-- Toggle between .rb and .html.erb for Ruby view components
vim.keymap.set('n', '<Leader>r', function() ruby_toggle.toggle_alternate() end,
  { noremap = true, silent = true, desc = "Toggle between .rb and .html.erb" })
