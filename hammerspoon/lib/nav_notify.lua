-- Shared one-second notification for the agent-notify navigation actions
-- (Cmd+L forward jump, Cmd+K return), so every keypress reports what it did.
-- Silent by design: the agent notification already played a sound, and these
-- fire on a deliberate keypress where a second chime is pure noise.
--
-- Usage:
--   local navNotify = require("nav_notify")
--   navNotify.show("→ mysession [nvim]", "Claude finished")

local M = {}

-- Seconds before macOS withdraws the banner. Kept short on purpose: while it
-- is on screen it is the topmost Notification Center alert, which is exactly
-- what click_notification targets — so a Cmd+L pressed inside this window
-- would activate this banner instead of the agent's own notification.
local WITHDRAW_AFTER = 1

-- Post `title` with `detail` as the subtitle. `detail` must be non-empty:
-- macOS renders a lone title in the subtitle slot, leaving the bold line
-- showing only the sending app's name ("Hammerspoon").
function M.show(title, detail)
  hs.notify.new({
    title = title,
    subTitle = detail,
    withdrawAfter = WITHDRAW_AFTER,
  }):send()
end

return M
