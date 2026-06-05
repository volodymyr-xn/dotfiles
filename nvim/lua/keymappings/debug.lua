-- Insert a language-appropriate debug statement (binding.pry, debugger,
-- etc.)
vim.keymap.set("n", "<leader>q", CustomInsertDebug, { noremap = true, silent = true, desc = "Insert debug statement" })
