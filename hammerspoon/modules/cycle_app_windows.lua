local M = {}

-- Cycle through windows of the frontmost app (layout-independent replacement
-- for macOS "Move focus to next window", which targets the physical key
-- above Tab and is unreliable on non-US layouts).
-- Focuses the BACK-MOST window of the app, not the second-front one:
-- focusing the second-front window just swaps it with the front window
-- and ping-pongs between two windows. Focusing the back-most rotates
-- the stack so all N windows cycle in order. Same trick the official
-- AppWindowSwitcher.spoon uses.
function M.cycle()
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

return M
