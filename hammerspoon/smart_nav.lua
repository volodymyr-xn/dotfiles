local clickNotification = require("click_notification")
local notifyReturn = require("notify_return")

local M = {}

-- Smart nav: open the topmost notification when one is showing, else return
-- to the pre-jump app via the stored back path. Lets one button drive both
-- the forward (open) and back (restore) phases of the agent-notify flow.
function M.navigate()
  if clickNotification.hasAny() then
    clickNotification.open()
  elseif notifyReturn.hasSnapshot() then
    notifyReturn.restoreFull()
  end
end

return M
