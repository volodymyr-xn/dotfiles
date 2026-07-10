local tmux = require("functions.tmux")

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

-- Send the line under the cursor + its @file:line reference to the AI pane
vim.keymap.set("n", "sm", tmux.send_line, { noremap = true, silent = true, desc = "Send current line to tmux AI pane" })
