-- Dashboard-local state for memory_manager. The cleanup engine's config and
-- runtime state live in `my_plugins.memory_cleaner.shared`; this module only
-- holds UI state that survives close+reopen within one nvim session.

local M = {}

M.dashboard_state = {
  sort = "size", folded = {},
  row_index = {}, buf = nil, win = nil, view = nil,
  hint_buf = nil, hint_win = nil,
}

return M
