local onediff = require("my_extensions.onediff")

onediff.setup({
  base_ref = "HEAD",
  sidebar = {
    width = 35,
    position = "left",
  },
})

vim.keymap.set("n", "<leader>do", onediff.open, { desc = "OneDiff: Open" })
vim.keymap.set("n", "<leader>dO", onediff.open_current, { desc = "OneDiff: Open current file" })
vim.keymap.set("n", "<leader>dc", onediff.close, { desc = "OneDiff: Close" })
vim.keymap.set("n", "<leader>dd", onediff.toggle, { desc = "OneDiff: Toggle" })
vim.keymap.set("n", "<leader>dr", onediff.refresh, { desc = "OneDiff: Refresh" })

vim.keymap.set("n", "]f", onediff.goto_next_file, { desc = "OneDiff: Next file" })
vim.keymap.set("n", "[f", onediff.goto_prev_file, { desc = "OneDiff: Prev file" })
vim.keymap.set("n", "]c", onediff.goto_next_change, { desc = "OneDiff: Next change" })
vim.keymap.set("n", "[c", onediff.goto_prev_change, { desc = "OneDiff: Prev change" })

vim.keymap.set("n", "<leader>ds", onediff.focus_sidebar, { desc = "OneDiff: Focus sidebar" })
vim.keymap.set("n", "<leader>db", onediff.toggle_sidebar, { desc = "OneDiff: Toggle sidebar" })
