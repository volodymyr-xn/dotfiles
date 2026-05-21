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

-- my_plugins/ settings. Order matters: fuzzy_picker_selector must run
-- before `keymappings/finders.lua` reads `.active`; memory_cleaner is
-- eager so its timers start regardless of dashboard use; memory_manager
-- registers a lazy `:MemDashboard` stub that loads the heavy dashboard on
-- first call.
require('plugin_settings/fuzzy_picker_selector')
require('plugin_settings/memory_cleaner')
require('plugin_settings/memory_manager')
require('plugin_settings/memory_monitor')
require('plugin_settings/git_diff_popup')
require('plugin_settings/ruby_component_toggle')

-- ====================== Vim highlight tag settings ======================
vim.cmd('highlight link matchTagError Todo')
vim.g.vim_matchtag_highlight_cursor_on = 1
