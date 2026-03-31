local tinygit = require("tinygit")

-- Interactively stage/unstage individual hunks via telescope
vim.keymap.set("n", "sgs", function() tinygit.interactiveStaging() end, { desc = "Tinygit: interactive staging" })
