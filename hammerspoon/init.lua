-- Open the IPC Mach port so the `hs` CLI can drive this running instance
require("hs.ipc")

local function volumeUp()
  hs.eventtap.event.newSystemKeyEvent("SOUND_UP", true):post()
  hs.eventtap.event.newSystemKeyEvent("SOUND_UP", false):post()
end

local function volumeDown()
  hs.eventtap.event.newSystemKeyEvent("SOUND_DOWN", true):post()
  hs.eventtap.event.newSystemKeyEvent("SOUND_DOWN", false):post()
end

-- Volume control: F10 up, F9 down
-- For keychron mechanic low profile keyboard
hs.hotkey.bind({}, "f10", volumeUp, nil, volumeUp)
hs.hotkey.bind({}, "f9", volumeDown, nil, volumeDown)

-- Volume control: Numpad +/- (raw keycodes: 69 = numpad+, 78 = numpad-)
-- For regular full width membrane keyboard
hs.hotkey.bind({}, 69, volumeUp, nil, volumeUp)
hs.hotkey.bind({}, 78, volumeDown, nil, volumeDown)

-- Mute/unmute: Numpad * (raw keycode 67)
local function toggleMute()
  hs.eventtap.event.newSystemKeyEvent("MUTE", true):post()
  hs.eventtap.event.newSystemKeyEvent("MUTE", false):post()
end
hs.hotkey.bind({}, 67, toggleMute)
hs.hotkey.bind({"cmd"}, "0", toggleMute)

-- Play/pause (continue) media playback: Numpad 0 (raw keycode 82)
local function togglePlayPause()
  hs.eventtap.event.newSystemKeyEvent("PLAY", true):post()
  hs.eventtap.event.newSystemKeyEvent("PLAY", false):post()
end
hs.hotkey.bind({}, 82, togglePlayPause)

-- Focus app or launch if not running
local function focusApp(name)
  hs.application.launchOrFocus(name)
end

local dismissNotifications = require("dismiss_notifications").dismiss
local openNotification = require("click_notification").open

-- Cmd+L → dismiss all notifications
hs.hotkey.bind({"cmd"}, "k", dismissNotifications)

-- Cmd+` → activate (click) the topmost notification's default action
hs.hotkey.bind({"cmd"}, "l", openNotification)

-- Cmd+` → cycle through windows of the frontmost app (layout-independent
-- replacement for macOS "Move focus to next window", which targets the
-- physical key above Tab and is unreliable on non-US layouts).
-- Focuses the BACK-MOST window of the app, not the second-front one:
-- focusing the second-front window just swaps it with the front window
-- and ping-pongs between two windows. Focusing the back-most rotates
-- the stack so all N windows cycle in order. Same trick the official
-- AppWindowSwitcher.spoon uses.
local function cycleAppWindows()
  local app = hs.application.frontmostApplication()
  if not app then return end
  local pid = app:pid()
  local target = nil
  for _, win in ipairs(hs.window.orderedWindows()) do
    if win:application():pid() == pid then
      target = win
    end
  end
  if target then target:focus() end
end

hs.hotkey.bind({"cmd"}, "`", cycleAppWindows)
