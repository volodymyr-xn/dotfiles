local onediff = require("my_extensions.onediff")

onediff.setup({
  base_ref = "HEAD",
  sidebar = {
    width = 35,
    position = "left",
  },
})

vim.api.nvim_create_user_command("OneDiff", onediff.toggle, { desc = "Toggle OneDiff" })
vim.api.nvim_create_user_command("OneDiffOpen", onediff.open, { desc = "Open OneDiff" })
vim.api.nvim_create_user_command("OneDiffClose", onediff.close, { desc = "Close OneDiff" })
vim.api.nvim_create_user_command("OneDiffRefresh", onediff.refresh, { desc = "Refresh OneDiff" })
vim.api.nvim_create_user_command("OneDiffNextFile", onediff.goto_next_file, { desc = "Go to next changed file" })
vim.api.nvim_create_user_command("OneDiffPrevFile", onediff.goto_prev_file, { desc = "Go to previous changed file" })
vim.api.nvim_create_user_command("OneDiffNextChange", onediff.goto_next_change, { desc = "Go to next change" })
vim.api.nvim_create_user_command("OneDiffPrevChange", onediff.goto_prev_change, { desc = "Go to previous change" })
vim.api.nvim_create_user_command("OneDiffFocusSidebar", onediff.focus_sidebar, { desc = "Focus sidebar" })
vim.api.nvim_create_user_command("OneDiffToggleSidebar", onediff.toggle_sidebar, { desc = "Toggle sidebar" })

vim.keymap.set("n", "<leader>do", onediff.open, { desc = "OneDiff: Open" })
vim.keymap.set("n", "<leader>dc", onediff.close, { desc = "OneDiff: Close" })
vim.keymap.set("n", "<leader>dd", onediff.toggle, { desc = "OneDiff: Toggle" })
vim.keymap.set("n", "<leader>dr", onediff.refresh, { desc = "OneDiff: Refresh" })

vim.keymap.set("n", "]f", onediff.goto_next_file, { desc = "OneDiff: Next file" })
vim.keymap.set("n", "[f", onediff.goto_prev_file, { desc = "OneDiff: Prev file" })
vim.keymap.set("n", "]c", onediff.goto_next_change, { desc = "OneDiff: Next change" })
vim.keymap.set("n", "[c", onediff.goto_prev_change, { desc = "OneDiff: Prev change" })

vim.keymap.set("n", "<leader>ds", onediff.focus_sidebar, { desc = "OneDiff: Focus sidebar" })
vim.keymap.set("n", "<leader>db", onediff.toggle_sidebar, { desc = "OneDiff: Toggle sidebar" })
