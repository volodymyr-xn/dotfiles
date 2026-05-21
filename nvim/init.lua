-- Enable the bytecode cache for Lua modules (20-30% startup speedup);
-- must run before any require() so cached modules are picked up.
vim.loader.enable()

-- mapleader must be set BEFORE lazy.setup(), otherwise lazy resolves
-- `<Leader>X` triggers with the default `\` mapleader and registers wrong
-- stubs (e.g. `\0` instead of `<Space>0`).
vim.g.mapleader = " "
vim.g.maplocalleader = ","

-- functions.utils defines globals (LightenColor, etc) used by plugin config
-- callbacks. It must run before lazy.setup() since plugin specs without lazy
-- triggers execute their `config = function()` during plugins_install.
-- Other functions/ modules that themselves depend on lazy plugins (e.g.
-- functions.tmux requires telescope) must load AFTER plugins_install.
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
require("my_plugins/git_diff_popup")
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
