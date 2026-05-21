local M = {}

local ax = require("hs.axuielement")

local SUBROLE_ALERT = "AXNotificationCenterAlert"
local SUBROLE_STACK = "AXNotificationCenterAlertStack"
-- Transient style ("Banners" in System Settings > Notifications); auto-dismisses.
local SUBROLE_BANNER = "AXNotificationCenterBanner"

-- NotificationCenter's localized name has a space ("Notification Center"); look up by bundle ID.
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
    if subrole == SUBROLE_ALERT or subrole == SUBROLE_STACK or subrole == SUBROLE_BANNER then
      table.insert(found, child)
    else
      collectAlerts(child, found)
    end
  end
end

-- Find every alert/stack element under NotificationCenter's first window.
local function findAlerts()
  local root = notificationCenter()

  if not root then return {} end

  local windows = root:attributeValue("AXWindows")

  if not windows or #windows == 0 then return {} end

  local found = {}
  collectAlerts(windows[1], found)

  return found
end

-- Prefer an individual banner over a collapsed stack for activation.
local function preferBanner(alerts)
  for _, alert in ipairs(alerts) do
    if alert:attributeValue("AXSubrole") == SUBROLE_ALERT then
      return alert
    end
  end

  return alerts[1]
end

-- Read the alert's actions as a list of {name, lowercased description}.
local function readActions(alert)
  local names = alert:actionNames() or {}
  local actions = {}

  for _, name in ipairs(names) do
    local desc = alert:actionDescription(name) or ""
    table.insert(actions, { name = name, desc = desc:lower() })
  end

  return actions
end

-- Pick the first action whose description contains `wanted` (lowercased).
local function findByDescription(actions, wanted)
  local needle = wanted:lower()

  for _, action in ipairs(actions) do
    if action.desc:find(needle, 1, true) then
      return action
    end
  end

  return nil
end

-- Default activation order: explicit show/open > AXPress > first non-dismiss.
local function findDefault(actions)
  for _, action in ipairs(actions) do
    if action.desc == "show" or action.desc == "open" then return action end
  end

  for _, action in ipairs(actions) do
    if action.name == "AXPress" then return action end
  end

  for _, action in ipairs(actions) do
    local d = action.desc
    if d ~= "close" and d ~= "clear all" and d ~= "options" then
      return action
    end
  end

  return nil
end

-- Activate the topmost notification; `wanted` matches an action description.
local function activate(wanted)
  local alerts = findAlerts()

  if #alerts == 0 then return end

  local alert = preferBanner(alerts)
  local actions = readActions(alert)
  local target = wanted and findByDescription(actions, wanted) or findDefault(actions)

  if target then alert:performAction(target.name) end
end

-- Activate the topmost notification's default action (open it).
function M.open()
  activate(nil)
end

-- True when at least one alert/banner/stack is currently in NotificationCenter.
function M.hasAny()
  return #findAlerts() > 0
end

-- Activate a named action button on the topmost notification (e.g. "Join").
function M.action(name)
  activate(name)
end

return M
