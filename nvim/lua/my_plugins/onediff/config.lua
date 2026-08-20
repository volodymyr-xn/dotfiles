-- OneDiff settings, split out of the implementation so plugin_settings can
-- configure them at startup without pulling in init.lua (which requires
-- gitsigns at its top and must therefore stay lazy until the first keypress).

local M = {}

M.options = {
  -- Show inline deleted-line virtual lines from session start. `<C-S-M>`
  -- flips this during a session regardless of the setting.
  show_deleted = false,
}

-- Merge user overrides over the defaults. Called from
-- plugin_settings/onediff.lua; safe to omit entirely.
function M.setup(opts)
  M.options = vim.tbl_extend("force", M.options, opts or {})
end

return M
