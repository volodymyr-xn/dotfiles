-- Memory manager lazy-loader.
--
-- The dashboard module is heavy (~1k LOC across dashboard/rpc/shared) and
-- only matters once the user actually opens it, so we register a thin stub
-- here that defers the require until first invocation.
--
-- The cleanup engine itself is set up eagerly by
-- `plugin_settings/memory_cleaner.lua` and is the always-on half of the pair.
--
-- Recursion-proof pattern: the stub calls the implementation directly via
-- the returned module table — NEVER via `vim.cmd("MemDashboard")` re-dispatch.
-- Re-dispatching would loop forever if the real module ever stopped
-- overriding the command (that bug bit `git_diff_popup` in c60748e and the
-- same trap was present here).

vim.api.nvim_create_user_command("MemDashboard", function()
  require("my_plugins.memory_manager").dashboard()
end, { desc = "Open memory dashboard" })

-- `sv` — quick open of the memory dashboard (cross-process buffer/parser/RSS view).
vim.keymap.set("n", "sv", ":MemDashboard<CR>", {
  noremap = true,
  silent = true,
  desc = "Open memory dashboard",
})
