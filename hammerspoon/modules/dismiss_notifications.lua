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

-- Dismiss-action label exposed by each subrole. Stacks expose "Clear All"
-- which closes every alert grouped under them in one call; singles only
-- expose "Close". Looking the wanted label up by subrole removes the
-- per-alert fallback ladder findDismissAction used to run.
local DISMISS_LABEL = {
  [SUBROLE_STACK]  = "Clear All",
  [SUBROLE_ALERT]  = "Close",
  [SUBROLE_BANNER] = "Close",
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

-- Walk `children`, appending dismissible entries {element, subrole} into
-- `found`. Returns true the moment a stack is captured: "Clear All" on a
-- stack dismisses every alert beneath it, so the caller can stop walking
-- entirely — the unwalked branches would only surface alerts that the
-- stack's Clear All is about to remove anyway. Carrying the subrole forward
-- means dismiss() doesn't re-query AXSubrole when picking the action.
local function collectAlerts(children, found)
  for _, child in ipairs(children) do
    local sub = child:attributeValue("AXSubrole")

    if sub == SUBROLE_STACK then
      found[#found + 1] = {element = child, subrole = sub}
      return true
    end

    if DISMISSIBLE_SUBROLES[sub] then
      found[#found + 1] = {element = child, subrole = sub}
    else
      local grandchildren = child:attributeValue("AXChildren")
      if grandchildren and collectAlerts(grandchildren, found) then
        return true
      end
    end
  end

  return false
end

-- Pick the dismiss action name for `alert` given its known `subrole`. Action
-- names embed a per-element target ("Name:Close\nTarget:0x...") so the full
-- name can't be cached across alerts — but DISMISS_LABEL fixes which label
-- to match per subrole, so we scan for exactly one label instead of running
-- the original Clear-All-then-Close fallback ladder.
local function findDismissAction(alert, subrole)
  local wanted = DISMISS_LABEL[subrole]
  if not wanted then return nil end

  local names = alert:actionNames()
  if not names then return nil end

  for _, name in ipairs(names) do
    if name:match("^Name:([^\n]+)") == wanted then return name end
  end

  return nil
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

  local children = ncWindow:attributeValue("AXChildren")
  if not children then return end

  local alerts = {}
  collectAlerts(children, alerts)

  for _, entry in ipairs(alerts) do
    local element = entry.element
    local action = findDismissAction(element, entry.subrole)
    if action then
      element:performAction(action)
    end
  end
end

return M
