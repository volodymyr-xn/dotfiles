local function volumeUp()
  hs.eventtap.event.newSystemKeyEvent("SOUND_UP", true):post()
  hs.eventtap.event.newSystemKeyEvent("SOUND_UP", false):post()
end

local function volumeDown()
  hs.eventtap.event.newSystemKeyEvent("SOUND_DOWN", true):post()
  hs.eventtap.event.newSystemKeyEvent("SOUND_DOWN", false):post()
end

-- Volume control: F10 up, F9 down
hs.hotkey.bind({}, "f10", volumeUp, nil, volumeUp)
hs.hotkey.bind({}, "f9", volumeDown, nil, volumeDown)

-- Volume control: Numpad +/- (raw keycodes: 69 = numpad+, 78 = numpad-)
hs.hotkey.bind({}, 69, volumeUp)
hs.hotkey.bind({}, 78, volumeDown)
