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
  local device = hs.audiodevice.defaultOutputDevice()
  device:setMuted(not device:muted())
end
hs.hotkey.bind({}, 67, toggleMute)

-- Focus app or launch if not running
local function focusApp(name)
  hs.application.launchOrFocus(name)
end

-- Ctrl+Cmd+T → Ghostty (terminal)
hs.hotkey.bind({"ctrl", "cmd"}, "t", function() focusApp("Ghostty") end)

-- Ctrl+Cmd+C → Google Chrome (browser)
hs.hotkey.bind({"ctrl", "cmd"}, "c", function() focusApp("Google Chrome") end)

local dismissNotifications = require("dismiss_notifications").dismiss

-- Cmd+L → dismiss all notifications
hs.hotkey.bind({"cmd"}, "l", dismissNotifications)
