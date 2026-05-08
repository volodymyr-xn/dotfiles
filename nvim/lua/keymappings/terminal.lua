local tmux = require("functions.tmux")
local tmux_watchers = require("functions.tmux_asset_watchers")

-- Escape terminal mode and navigate to adjacent tmux/nvim pane
local terminal_opts = { silent = true, noremap = true }
vim.keymap.set("t", "<C-h>", [[<C-\><C-n><Cmd>TmuxNavigateLeft<CR>]], terminal_opts)
vim.keymap.set("t", "<C-j>", [[<C-\><C-n><Cmd>TmuxNavigateDown<CR>]], terminal_opts)
vim.keymap.set("t", "<C-k>", [[<C-\><C-n><Cmd>TmuxNavigateUp<CR>]], terminal_opts)
vim.keymap.set("t", "<C-l>", [[<C-\><C-n><Cmd>TmuxNavigateRight<CR>]], terminal_opts)

-- Send current file path to the active tmux pane
vim.keymap.set("n", "<Leader>`", tmux.send_file, { noremap = true, silent = true, desc = "Send file path to tmux" })

-- Send file path + visual selection range to the active tmux pane
vim.keymap.set("v", "<Leader>`", tmux.send_selection, { noremap = true, silent = true, desc = "Send file + selection to tmux" })

-- Restart all yarn watch processes running in the current tmux session
vim.keymap.set("n", "<Leader>rw", tmux_watchers.restart_watchers, { noremap = true, silent = true, desc = "Restart yarn watch commands" })
