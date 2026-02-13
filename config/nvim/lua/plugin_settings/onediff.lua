local onediff_loaded = false

local function load_onediff()
  if onediff_loaded then
    return require("my_extensions.onediff")
  end
  
  local onediff = require("my_extensions.onediff")
  local onediff_debug = require("my_extensions.onediff.debug_helper")
  
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
