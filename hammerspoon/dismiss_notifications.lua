local ax = require("hs.axuielement")
local SUBROLES = { AXNotificationCenterAlert = true, AXNotificationCenterAlertStack = true }
local CLOSE_ACTIONS = { ["Clear All"] = true, Close = true }

local function findAlerts(el, alerts)
  alerts = alerts or {}
  local sr = el:attributeValue("AXSubrole")
  if sr and SUBROLES[sr] then
    alerts[#alerts + 1] = el
  else
    for _, child in ipairs(el:attributeValue("AXChildren") or {}) do
      findAlerts(child, alerts)
    end
  end
  return alerts
end

local function dismiss()
  local apps = ax.applicationElement(hs.application.find("NotificationCenter"))
  if not apps then return end
  local wins = apps:attributeValue("AXWindows")
  if not wins or #wins == 0 then return end
  for _, alert in ipairs(findAlerts(wins[1])) do
    for _, action in ipairs(alert:attributeValue("AXActions") or {}) do
      local desc = alert:actionDescription(action)
      if CLOSE_ACTIONS[desc] then
        alert:performAction(action)
        break
      end
    end
  end
end

return { dismiss = dismiss }
