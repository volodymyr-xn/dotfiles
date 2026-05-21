-- Ruby component toggle loader — the module has no configurable surface;
-- it exports pure navigation helpers (`navigate_to_extension`,
-- `navigate_to_style`) used by the `s1`–`s4` keymaps in
-- `keymappings/files.lua`. Lives in plugin_settings/ for symmetry with
-- the rest of `my_plugins/`; if real knobs appear later (e.g. configurable
-- extension list), add them as a `setup({...})` call here.

require("my_plugins.ruby_component_toggle")
