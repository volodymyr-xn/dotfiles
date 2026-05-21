-- Memory manager setup — registers the lazy `:MemDashboard` user command.
--
-- The dashboard module is heavy and only needed when the command runs, so
-- we register a thin stub here that requires the real module on first
-- invocation (its setup() replaces this stub with the real command and
-- then we re-dispatch). The cleanup engine itself is set up by
-- `plugin_settings/memory_cleaner.lua` and is the eager half of the pair.

vim.api.nvim_create_user_command("MemDashboard", function()
  require("my_plugins.memory_manager").setup()
  vim.cmd("MemDashboard")
end, {})
