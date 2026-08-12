local M = {}

-- Echo a plugin-prefixed warning that is kept in :messages.
function M.warn(msg)
  vim.api.nvim_echo({ { "Ack: " .. msg, "WarningMsg" } }, true, {})
end

return M
