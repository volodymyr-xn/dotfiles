-- Memory Manager — lazy-loaded dashboard for the cleanup engine.
--
-- The actual cleanup engine (timers, autocmds, prune logic, :MemClear) lives
-- in `my_plugins.memory_cleaner` and loads eagerly at startup. This module
-- just owns the cross-process dashboard float and its actions.
--
-- The `:MemDashboard` user command is registered by the lazy-load stub in
-- `plugin_settings/memory_manager.lua`, which calls `M.dashboard()` directly
-- (no `vim.cmd("MemDashboard")` re-dispatch — that pattern would infinite-
-- loop if the override here ever went missing).
--
-- Public surface:
--   require("my_plugins.memory_manager").dashboard()  -- open the float

local shared = require("my_plugins.memory_manager.shared")
local dashboard = require("my_plugins.memory_manager.dashboard")

local M = {}

M.dashboard_state = shared.dashboard_state
M.dashboard = dashboard.open

return M
