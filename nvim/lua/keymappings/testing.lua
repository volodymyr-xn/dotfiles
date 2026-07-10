local test_runner = require("functions.test_runner")

-- vim-test mappings. Routed through test_runner so the command lands in an
-- idle tmux pane instead of whichever pane Vimux happens to pick.
local test_opts = { silent = true, noremap = true }

vim.keymap.set("n", "<Leader>t", function() test_runner.run("TestNearest") end,
  vim.tbl_extend("force", test_opts, { desc = "Test nearest" }))

vim.keymap.set("n", "<Leader>T", function() test_runner.run("TestFile") end,
  vim.tbl_extend("force", test_opts, { desc = "Test file" }))

vim.keymap.set("n", "<Leader>l", function() test_runner.run("TestLast") end,
  vim.tbl_extend("force", test_opts, { desc = "Test last" }))
