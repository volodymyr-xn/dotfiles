-- Git diff popup lazy-loader — defers requiring `my_plugins.git_diff_popup`
-- (~140 LOC) until `:GitDiffPopup` is invoked.
--
-- Recursion-proof pattern: the stub `require`s the implementation and calls
-- its global function directly — NEVER `vim.cmd("GitDiffPopup")`. The
-- re-dispatch trap (call the same command from inside its own callback)
-- caused the infinite `nvim_exec2()` loop fixed in 40acc48; do not
-- reintroduce it. `require` is itself cached, so calling it on every
-- invocation is effectively free after the first hit.
--
-- The `sd` keymap stays here as a cmdline shortcut to `:GitDiffPopup<CR>`
-- — it doesn't need the module to be loaded to take effect.

vim.api.nvim_create_user_command("GitDiffPopup", function()
  require("my_plugins.git_diff_popup").open()
end, { desc = "Show git diff popup for current file" })

vim.keymap.set("n", "sd", ":GitDiffPopup<CR>", {
  noremap = true,
  silent = true,
  desc = "Show git diff popup",
})
