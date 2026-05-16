local M = {}

-- Single-quote a string so it survives as one shell argument.
local function shellQuote(value)
  return "'" .. value:gsub("'", "'\\''") .. "'"
end

-- Absolute path to the JXA notification helper (lives outside PATH)
local SCRIPT_ARG = shellQuote(
  os.getenv("HOME") .. "/dotfiles/scripts/c-macos-click-notification.js"
)

-- Activate the topmost notification's default action (open it).
function M.open()
  hs.execute(SCRIPT_ARG, true)
end

-- Activate a named action button on the topmost notification (e.g. "Join").
function M.action(name)
  hs.execute(SCRIPT_ARG .. " " .. shellQuote(name), true)
end

return M
