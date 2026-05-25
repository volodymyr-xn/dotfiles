-- `vim.loader.enable()` is intentionally NOT called.
--
-- The bytecode cache (~/.cache/nvim/luac/) gives a ~20–30% startup speedup
-- but desyncs with source files in this config's setup: the symlink chain
-- ~/.config/nvim → ~/dotfiles/nvim → ~/Meta/.../nvim and atomic editor
-- writes can leave the loader serving stale `.luac` after a source-file
-- fix. That was the root cause of the recurring git_diff_popup recursion
-- bug that "kept coming back" across three separate fixes — the fixes
-- were correct; the bytecode wasn't.
--
-- 100ms of cold startup is a fine trade for never debugging phantom-cache
-- bugs again. If startup time ever becomes the bottleneck, re-enable here
-- AND pair it with a `BufWritePost` autocmd that calls `vim.loader.reset`
-- on saved config files (see git history of autocommands.lua for the
-- pattern), plus a `:Reload` command that wipes the cache before
-- re-sourcing.

-- mapleader must be set BEFORE lazy.setup(), otherwise lazy resolves
-- `<Leader>X` triggers with the default `\` mapleader and registers wrong
-- stubs (e.g. `\0` instead of `<Space>0`).
vim.g.mapleader = " "
vim.g.maplocalleader = ","

-- functions.utils defines globals (LightenColor, etc) used by plugin config
-- callbacks. It must run before lazy.setup() since plugin specs without lazy
-- triggers execute their `config = function()` during plugins_install.
-- Other functions/ modules can load in any order — modules that talk to
-- lazy plugins (e.g. functions.tmux uses telescope) defer their requires
-- into function bodies so they don't pull lazy plugins in at startup.
require("functions.utils")

require("plugins_install")
require("general_settings")
require("colors")
require("functions.temp_fix_util")
require("functions.nvim_compat")
require("functions.snippet_generators")
require("functions.tmux")
require("functions.git_hunk")
require("plugins_require")
require("plugins_to_test_require")
require("commands")
require("autocommands")
require("keymappings.navigation")
require("keymappings.windows")
require("keymappings.editing")
require("keymappings.files")
require("keymappings.search")
require("keymappings.git")
require("keymappings.testing")
require("keymappings.terminal")
require("keymappings.debug")
require("keymappings.finders")
require("highlight")
require("ui2")
