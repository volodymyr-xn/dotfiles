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

-- Focus app or launch if not running
local function focusApp(name)
  hs.application.launchOrFocus(name)
end

local dismissNotifications = require("dismiss_notifications").dismiss
local openNotification = require("click_notification").open

-- Cmd+L → dismiss all notifications
hs.hotkey.bind({"cmd"}, "l", dismissNotifications)

-- Cmd+` → activate (click) the topmost notification's default action
hs.hotkey.bind({"cmd"}, "`", openNotification)
