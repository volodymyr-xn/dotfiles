-- Lazy-load OneDiff on first keypress. Lua's `require` is itself memoized,
-- so the early-return branch is just to skip the one-time `setup()` call —
-- not to avoid re-requiring. The flag is set BEFORE `setup()` runs so that
-- if setup throws partway, the next keypress doesn't re-run side effects
-- like duplicate `OneDiff*` command registration. Recovery from a broken
-- setup needs a full nvim restart, which is acceptable for a config-error.
local onediff_loaded = false

local function load_onediff()
  local onediff = require("my_plugins.onediff")

  if onediff_loaded then
    return onediff
  end

  onediff_loaded = true
  require("my_plugins.onediff.debug_helper")

  onediff.setup({
    base_ref = "HEAD",
    picker = "telescope",
    sidebar = {
      width = 47,
      position = "left",
    },
  })

  return onediff
end

vim.keymap.set("n", "sf", function()
  local onediff = load_onediff()
  onediff.open_or_focus_and_refresh()
end, { desc = "Open/focus OneDiff and refresh" })

-- Disable Vim's default Q (Ex mode) so it doesn't fire accidentally.
vim.keymap.set("n", "Q", "<Nop>", { desc = "Disabled" })

-- Quick-open OneDiff with capital M.
-- Pressing M again while focused inside any OneDiff buffer closes the session.
vim.keymap.set("n", "M", function()
  local onediff = load_onediff()
  local session = require("my_plugins.onediff.session")
  local buf = vim.api.nvim_get_current_buf()
  if session.is_open() and vim.b[buf].onediff_instance_id then
    onediff.close()
  else
    onediff.open_or_focus_and_refresh()
  end
end, { desc = "Toggle OneDiff (open/focus, or close when inside)" })
