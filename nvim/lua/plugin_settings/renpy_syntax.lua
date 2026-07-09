-- Ren'Py syntax, indentation, ft detection and the optional cmp source. The
-- plugin registers its `renpy` nvim-cmp source lazily on the first
-- `FileType renpy` event (guarded by pcall), and plugin_settings/nvim_cmp.lua
-- wires that source into completion for renpy buffers. setup() takes no args.
require("renpy-syntax").setup()
