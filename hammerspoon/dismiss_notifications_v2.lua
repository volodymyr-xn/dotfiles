local M = {}

local ax = require("hs.axuielement")

local SUBROLE_ALERT = "AXNotificationCenterAlert"
local SUBROLE_STACK = "AXNotificationCenterAlertStack"
local SUBROLE_BANNER = "AXNotificationCenterBanner"

-- The NC window that hosts banners/alerts. Other AXWindows belong to widgets
-- (Month, Forecast, Clock, ...) and never contain notifications.
local SUBROLE_NC_WINDOW = "AXSystemDialog"

-- Subroles that represent a dismissible notification surface. Set is used
-- for O(1) lookup in the AX tree walk. Banner is the transient style modern
-- macOS uses by default; Alert/AlertStack appear when an app is configured
-- to use the persistent "Alerts" notification style.
local DISMISSIBLE_SUBROLES = {
  [SUBROLE_ALERT]  = true,
  [SUBROLE_STACK]  = true,
  [SUBROLE_BANNER] = true,
}

-- NotificationCenter's localized name has a space; look it up by bundle id.
local NC_BUNDLE = "com.apple.notificationcenterui"

-- Cached AX root for NotificationCenter; the process never restarts in
-- practice, so we skip the ~0.2 ms hs.application.get() lookup per call.
-- Self-heals: M.dismiss() clears this if AXWindows ever returns nil.
local cachedRoot = nil

-- Get the AX root for NotificationCenter, or nil if it isn't running.
local function notificationCenter()
  if cachedRoot then return cachedRoot end
  local app = hs.application.get(NC_BUNDLE)
  if not app then return nil end
  cachedRoot = ax.applicationElement(app)
  return cachedRoot
end

-- Walk descendants of `element`, appending dismissible alert subroles into `found`.
local function collectAlerts(element, found)
  local children = element:attributeValue("AXChildren")

  if not children then return end

  for _, child in ipairs(children) do
    if DISMISSIBLE_SUBROLES[child:attributeValue("AXSubrole")] then
      table.insert(found, child)
    else
      collectAlerts(child, found)
    end
  end
end

-- Pick the best dismiss action for an alert: prefer "Clear All" (stacks),
-- fall back to "Close" (single alert/banner). Matches the "Name:<label>"
-- line embedded in each AX action name (e.g. "Name:Close\nTarget:0x0...")
-- so we make a single :actionNames() call instead of N :actionDescription()
-- round trips per alert.
local function findDismissAction(alert)
  local names = alert:actionNames() or {}
  local close

  for _, name in ipairs(names) do
    local label = name:match("^Name:([^\n]+)")
    if label == "Clear All" then return name end
    if label == "Close" then close = name end
  end

  return close
end

-- Dismiss every notification: prefer "Clear All" on stacks, else "Close".
function M.dismiss()
  local root = notificationCenter()

  if not root then return end

  local windows = root:attributeValue("AXWindows")

  if not windows then
    -- Cached root went stale (NC restarted); drop it so the next call refetches.
    cachedRoot = nil
    return
  end

  if #windows == 0 then return end

  -- The banner-host window is always windows[1] when present (NC prepends it),
  -- with subrole AXSystemDialog. At idle, windows[1] is a widget (Calendar,
  -- Clock, ...) — check the subrole so we can bail without walking the
  -- widget tree.
  local ncWindow = windows[1]
  if ncWindow:attributeValue("AXSubrole") ~= SUBROLE_NC_WINDOW then return end

  local alerts = {}
  collectAlerts(ncWindow, alerts)

  for _, alert in ipairs(alerts) do
    local action = findDismissAction(alert)
    if action then
      pcall(function() alert:performAction(action) end)
    end
  end
end

return M
