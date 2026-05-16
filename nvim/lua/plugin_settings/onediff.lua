local onediff_loaded = false

local function load_onediff()
  if onediff_loaded then
    return require("my_plugins.onediff")
  end
  
  local onediff = require("my_plugins.onediff")
  local onediff_debug = require("my_plugins.onediff.debug_helper")
  
  onediff.setup({
    base_ref = "HEAD",
    picker = "telescope",
    sidebar = {
      width = 47,
      position = "left",
    },
  })
  
  onediff_loaded = true
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
