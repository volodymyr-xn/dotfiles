local M = {}

-- Post a press+release of one system key event (volume, mute, play, …).
local function postSystemKey(name)
  hs.eventtap.event.newSystemKeyEvent(name, true):post()
  hs.eventtap.event.newSystemKeyEvent(name, false):post()
end

-- Step volume up by one notch.
function M.volumeUp()
  postSystemKey("SOUND_UP")
end

-- Step volume down by one notch.
function M.volumeDown()
  postSystemKey("SOUND_DOWN")
end

-- Toggle system mute.
function M.toggleMute()
  postSystemKey("MUTE")
end

-- Toggle media playback (play/pause).
function M.togglePlayPause()
  postSystemKey("PLAY")
end

return M
