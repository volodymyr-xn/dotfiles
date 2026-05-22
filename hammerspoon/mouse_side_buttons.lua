local canvasBanner = require("canvas_banner")
local notifyReturn = require("notify_return")
local smartNav = require("smart_nav")

-- otherMouseDown button numbers (0-indexed):
--   3 = bottom side button (closer to wrist)   → smart nav (open notification
--       or restore previous app via the stored back path)
--   4 = top side button (closer to fingers)    → App Exposé / Mission Control
-- Cmd + top button → notify_return.restoreFull (mouse mirror of Cmd+K)
-- Swap the button numbers below if your mouse maps them the other way.
local TOP_MOUSE_BUTTON = 4
local BOTTOM_MOUSE_BUTTON = 3

-- Module-level enable flag; when false, handle() returns early and lets the
-- OS receive the raw button event (so games using mouse 3/4 keep working).
local enabled = true

-- Dispatch one otherMouseDown event to the matching action; true swallows
-- the event so the OS does not also receive it, false lets it pass through.
local function handle(event)
  if not enabled then return false end

  local button = event:getProperty(hs.eventtap.event.properties.mouseEventButtonNumber)
  local flags = event:getFlags()

  if button == BOTTOM_MOUSE_BUTTON then
    if flags.cmd then
      notifyReturn.restoreFull()
    else
      hs.spaces.toggleMissionControl()
    end
    return true
  elseif button == TOP_MOUSE_BUTTON then
    smartNav.navigate()
    return true
  end

  return false
end

-- Module-local keeps the tap alive across the module's lifetime (Lua caches
-- required modules, so this upvalue survives garbage collection).
local tap = hs.eventtap.new({ hs.eventtap.event.types.otherMouseDown }, handle)
tap:start()

-- Flip the enable flag and surface the new state via the canvas banner.
local function toggle()
  enabled = not enabled

  canvasBanner.show({
    title = enabled and "Side buttons: ON" or "Side buttons: OFF",
    subtitle = enabled
      and "Hammerspoon mappings active"
      or "Passing through to apps",
    state = enabled and "on" or "off",
  })
end

return {
  tap = tap,
  toggle = toggle,
  isEnabled = function() return enabled end,
}
