-- Close current window
vim.api.nvim_set_keymap('n', '<C-c>', '<C-w>q', { noremap = true, desc = "Close window" })

-- Maximize current window
vim.api.nvim_set_keymap('n', '"', '<C-W>|<C-W>_', { noremap = true, desc = "Maximize window" })

-- Re-balance all window sizes equally
vim.api.nvim_set_keymap('n', '=', '<C-W>=', { noremap = true, desc = "Balance windows" })

-- Toggle zoom on current window (custom command)
vim.api.nvim_set_keymap('n', 'm', ':ToggleCurrentWindowZoom<CR>', { noremap = true, silent = true, desc = "Toggle window zoom" })

-- Resize windows by 5 columns/rows
vim.api.nvim_set_keymap('n', '<', '<C-w>5<', { noremap = true, desc = "Decrease window width" })
vim.api.nvim_set_keymap('n', '>', '<C-w>5>', { noremap = true, desc = "Increase window width" })
vim.api.nvim_set_keymap('n', '+', '<C-w>5+', { noremap = true, desc = "Increase window height" })
vim.api.nvim_set_keymap('n', '_', '<C-w>5-', { noremap = true, desc = "Decrease window height" })

-- Open new tab
vim.api.nvim_set_keymap('n', '<c-t>', '<esc>:tabnew<CR>', { silent = true, noremap = true, desc = "Open new tab" })

-- Close all tabs except current
vim.api.nvim_set_keymap('n', '<Leader>qa', ':tabonly<CR>', { noremap = true, desc = "Close all other tabs" })

-- Tab navigation
vim.api.nvim_set_keymap('n', '<C-e>', ':tabnext<CR>', { noremap = true, silent = true, desc = "Next tab" })
vim.api.nvim_set_keymap('n', '<M-j>', ':tabnext<CR>', { noremap = true, silent = true, desc = "Next tab" })
vim.api.nvim_set_keymap('n', '<M-k>', ':tabprev<CR>', { noremap = true, silent = true, desc = "Previous tab" })
vim.keymap.set("n", "K", ":tabnext<CR>", { noremap = true, silent = true, desc = "Next tab" })

-- Jump to tab N by index
for i = 1, 9 do
  vim.api.nvim_set_keymap('n', '<C-w>'..i, i..'gt<CR>', { noremap = true, desc = "Go to tab " .. i })
  vim.api.nvim_set_keymap('n', '<Leader>'..i, i..'gt<CR>', { noremap = true, desc = "Go to tab " .. i })
end
