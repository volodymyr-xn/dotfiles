local M = {}

local ax = require("hs.axuielement")

local SUBROLE_ALERT = "AXNotificationCenterAlert"
local SUBROLE_STACK = "AXNotificationCenterAlertStack"

-- NotificationCenter's localized name has a space; look it up by bundle id.
local NC_BUNDLE = "com.apple.notificationcenterui"

-- Get the AX root for NotificationCenter, or nil if it isn't running.
local function notificationCenter()
  local app = hs.application.get(NC_BUNDLE)
  return app and ax.applicationElement(app) or nil
end

-- Walk descendants of `element`, appending alert/stack subroles into `found`.
local function collectAlerts(element, found)
  local children = element:attributeValue("AXChildren")

  if not children then return end

  for _, child in ipairs(children) do
    local subrole = child:attributeValue("AXSubrole")
    if subrole == SUBROLE_ALERT or subrole == SUBROLE_STACK then
      table.insert(found, child)
    else
      collectAlerts(child, found)
    end
  end
end

-- Find the action whose description equals `wanted` (case-insensitive).
local function findActionByDescription(alert, wanted)
  local names = alert:actionNames() or {}
  local needle = wanted:lower()

  for _, name in ipairs(names) do
    local desc = alert:actionDescription(name) or ""
    if desc:lower() == needle then return name end
  end

  return nil
end

-- Dismiss every notification: prefer "Clear All" on stacks, else "Close".
function M.dismiss()
  local root = notificationCenter()

  if not root then return end

  local windows = root:attributeValue("AXWindows")

  if not windows or #windows == 0 then return end

  local alerts = {}
  collectAlerts(windows[1], alerts)

  for _, alert in ipairs(alerts) do
    local action = findActionByDescription(alert, "Clear All")
                or findActionByDescription(alert, "Close")
    if action then
      pcall(function() alert:performAction(action) end)
    end
  end
end

return M
