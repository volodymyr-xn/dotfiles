-- Open the IPC Mach port so the `hs` CLI can drive this running instance.
-- Without this require, `hs -c "..."` (the CLI shipped with Hammerspoon)
-- has nothing to talk to — no Mach port is listening, so every shell-side
-- call fails silently or with "Hammerspoon is not running". This powers
-- `bin/c-hammerspoon-reload` and any other shell tooling that injects Lua
-- into the live config (debug one-liners, scripts that toggle features).
-- Kept at the very top so the port comes up even if a later require() in
-- this file blows up — otherwise a syntax error somewhere below would
-- lock us out of the CLI and force quitting/reopening the Hammerspoon
-- app to recover.
require("hs.ipc")

local clickNotification = require("click_notification")
local cycleAppWindows = require("cycle_app_windows")
local dismissNotifications = require("dismiss_notifications").dismiss
local mediaKeys = require("media_keys")
local notifyReturn = require("notify_return")
-- Starts the side-button eventtap and exposes a toggle to mute its
-- mappings (so games binding mouse 3/4 keep receiving the raw clicks).
local mouseSideButtons = require("mouse_side_buttons")

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

-- Cmd+- → toggle mouse side-button mappings (off = pass through to games)
hs.hotkey.bind({"cmd"}, "n", mouseSideButtons.toggle)
