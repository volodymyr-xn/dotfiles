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

-- Idle-buffer unload, RSS notifier, lualine stats, and :MemDashboard.
require('my_plugins/memory_manager').setup()

-- ====================== Vim highlight tag settings ======================
vim.cmd('highlight link matchTagError Todo')
vim.g.vim_matchtag_highlight_cursor_on = 1
