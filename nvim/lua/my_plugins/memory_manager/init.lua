-- Memory Manager — lazy-loaded dashboard for the cleanup engine.
--
-- The actual cleanup engine (timers, autocmds, prune logic, :MemPrune) lives
-- in `my_plugins.memory_cleaner` and loads eagerly at startup. This module
-- just owns the cross-process dashboard float and its actions.
--
-- Public surface:
--   require("my_plugins.memory_manager").setup()  -- registers :MemDashboard
--   .dashboard()                                  -- open the float directly

local api = vim.api

local shared = require("my_plugins.memory_manager.shared")
local dashboard = require("my_plugins.memory_manager.dashboard")

local M = {}

M.dashboard_state = shared.dashboard_state
M.dashboard = dashboard.open

-- One-time wiring. Idempotent via the augroup `clear = true`.
function M.setup()
  api.nvim_create_user_command("MemDashboard", function() dashboard.open() end, {})
end

return M
