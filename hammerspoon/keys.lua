-- Every global hotkey binding lives here, so a new binding never has to be
-- hunted for across modules and conflicts are visible in one file.
-- Loaded last by init.lua, after package.path is extended so the module
-- requires below resolve out of modules/.

local brightness = require("brightness")
local caffeine = require("caffeine")
local clickNotification = require("click_notification")
local cycleAppWindows = require("cycle_app_windows")
local dismissNotifications = require("dismiss_notifications").dismiss
local mediaKeys = require("media_keys")
local mouseSideButtons = require("mouse_side_buttons")
local notifyReturn = require("notify_return")
local swichMonitorFocus = require("swich_monitor_focus")

-- External display brightness over DDC: F6 up, F5 down
-- Mirrors the F10/F9 volume direction; held keys ramp.
hs.hotkey.bind({}, "f6", brightness.up, nil, brightness.up)
hs.hotkey.bind({}, "f5", brightness.down, nil, brightness.down)

-- Volume control: F10 up, F9 down
-- For keychron mechanic low profile keyboard
hs.hotkey.bind({}, "f10", mediaKeys.volumeUp, nil, mediaKeys.volumeUp)
hs.hotkey.bind({}, "f9", mediaKeys.volumeDown, nil, mediaKeys.volumeDown)

-- Volume control: Numpad +/- (raw keycodes: 69 = numpad+, 78 = numpad-)
-- For regular full width membrane keyboard
hs.hotkey.bind({}, 69, mediaKeys.volumeUp, nil, mediaKeys.volumeUp)
hs.hotkey.bind({}, 78, mediaKeys.volumeDown, nil, mediaKeys.volumeDown)

-- Mute/unmute: Numpad * (raw keycode 67)
hs.hotkey.bind({}, 67, mediaKeys.toggleMute)

-- Play/pause (continue) media playback: Numpad 0 (raw keycode 82)
hs.hotkey.bind({}, 82, mediaKeys.togglePlayPause)

-- Cmd+K → return to the pre-jump app (+ tmux loc if it was Ghostty)
hs.hotkey.bind({"cmd"}, "k", notifyReturn.restoreFull)

-- Cmd+0 → dismiss all notifications (numpad * keycode 67 still toggles mute)
hs.hotkey.bind({"cmd"}, "i", dismissNotifications)

-- Cmd+L → activate (click) the topmost notification's default action
hs.hotkey.bind({"cmd"}, "l", clickNotification.open)

-- Cmd+` → cycle through windows of the frontmost app
hs.hotkey.bind({"cmd"}, "`", cycleAppWindows.cycle)

-- Cmd+E → App Exposé (current app windows overview)
hs.hotkey.bind({"cmd"}, "e", function()
  hs.spaces.toggleAppExpose()
end)

-- Cmd+M → toggle keep-awake (blocks display + system idle sleep)
hs.hotkey.bind({"cmd"}, "m", caffeine.toggle)

-- Cmd+Shift+M → toggle mouse side-button mappings (off = pass through to games)
hs.hotkey.bind({"cmd", "shift"}, "n", mouseSideButtons.toggle)

-- Cmd+Alt+M → move the mouse to the next monitor and focus its front window
hs.hotkey.bind({"cmd", "alt"}, "m", swichMonitorFocus.cycle)
