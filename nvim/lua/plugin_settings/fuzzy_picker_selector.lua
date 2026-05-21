-- Fuzzy picker selector setup — picks which file-picker frontend the
-- finder keymaps use (telescope / fzf_lua / fzf_vim / fff) and persists
-- the choice across sessions.
--
-- Keymaps and :PickerSwitch / :PickerSet commands live in
-- `keymappings/finders.lua`, which requires this module after setup() has
-- run (wired in `plugins_require.lua`).

require("my_plugins.fuzzy_picker_selector").setup({
  -- Available picker frontends in cycle order. Each name must match a
  -- module under `lua/custom_file_selectors/<name>.lua`.
  pickers = { "telescope", "fzf_lua", "fzf_vim", "fff" },

  -- Picker chosen when no prior selection is persisted (first run, or
  -- the state file was wiped). Must be one of `pickers`.
  default_picker = "telescope",

  -- Where the current picker name is persisted between sessions.
  state_file = vim.fn.stdpath("data") .. "/ultraselect_picker",
})
