-- All plugin-scoped setup files now live in each plugin's `config = function()`
-- block in plugins_install.lua. This file only loads custom code that is NOT
-- tied to a lazy.nvim plugin spec (local utilities, custom keymaps).

require("plugin_settings/icons")
require('plugin_settings/ack')
require('plugin_settings/ctags')
require('plugin_settings/ts_autotag')
require('plugin_settings/vim_illuminate')
require('plugin_settings/comment_nvim')
require('plugin_settings/quickfix')
require('plugin_settings/1_ror')
require('plugin_settings/onediff')
require('plugin_settings/markdown_preview')
require('plugin_settings/markdown_html_preview')

-- Memory cleaner is the schedule-driven cleanup engine; it owns the autocmds,
-- 60s prune timer, 20-min RSS sampler, and :MemPrune. Loaded eagerly so the
-- timers start ticking even when the dashboard is never opened. The settings
-- file overrides timing knobs on `.config` and must run before `.setup()`.
require('plugin_settings/memory_cleaner')
require("my_plugins.memory_cleaner").setup()

-- Memory manager is the cross-process dashboard. Lazy-loaded on first
-- :MemDashboard call: the stub below requires the real module (whose setup()
-- replaces this stub with the real command), then re-dispatches.
vim.api.nvim_create_user_command("MemDashboard", function()
  require("my_plugins.memory_manager").setup()
  vim.cmd("MemDashboard")
end, {})

-- ====================== Vim highlight tag settings ======================
vim.cmd('highlight link matchTagError Todo')
vim.g.vim_matchtag_highlight_cursor_on = 1
