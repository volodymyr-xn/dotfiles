local M = {}

-- Center point of a frame, as the table hs.mouse.absolutePosition expects.
local function centerOf(frame)
  return { x = frame.x + frame.w / 2, y = frame.y + frame.h / 2 }
end

-- Topmost standard window living on the given screen, or nil if that screen
-- shows only the desktop. orderedWindows() is front-to-back, so the first
-- match is the most recently used window there — the one the user means by
-- "the window on that monitor".
local function frontmostWindowOnScreen(screen)
  local screenId = screen:id()

  for _, window in ipairs(hs.window.orderedWindows()) do
    local windowScreen = window:screen()

    if windowScreen and windowScreen:id() == screenId and window:isStandard() then
      return window
    end
  end

  return nil
end

-- Warp the cursor to the next screen and move keyboard focus with it.
-- Two halves that macOS keeps separate: hs.mouse.absolutePosition only moves
-- the pointer (focus stays on the frontmost window wherever it is), so the
-- window has to be :focus()ed explicitly. With no window on the target
-- screen, Finder is activated so focus still leaves the old monitor instead
-- of silently staying behind the pointer.
function M.cycle()
  local currentScreen = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
  local targetScreen = currentScreen:next()

  if targetScreen:id() == currentScreen:id() then
    return
  end

  local targetWindow = frontmostWindowOnScreen(targetScreen)

  if targetWindow then
    targetWindow:focus()
    hs.mouse.absolutePosition(centerOf(targetWindow:frame()))

    return
  end

  hs.mouse.absolutePosition(centerOf(targetScreen:fullFrame()))
  hs.application.launchOrFocus("Finder")
end

return M
