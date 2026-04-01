local M = {}

function M.dismiss()
  hs.execute("c-macos-dismiss-notifications", true)
end

return M
