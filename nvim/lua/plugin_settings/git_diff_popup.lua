-- Git diff popup loader — the module has no configurable surface; it
-- simply defines the global `GitDiffCurrentFilePopup()` function used by
-- the diff keymap. Lives in plugin_settings/ for symmetry with the rest
-- of `my_plugins/`; if real knobs appear later, add them as a `setup({...})`
-- call here.

require("my_plugins.git_diff_popup")
