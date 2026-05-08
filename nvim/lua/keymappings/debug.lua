-- Insert a language-appropriate debug statement (binding.pry, debugger, etc.)
vim.keymap.set("n", "<leader>K", CustomInsertDebug, { noremap = true, silent = true, desc = "Insert debug statement" })
