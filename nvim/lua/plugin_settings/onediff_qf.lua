-- OneDiff v2 (quickfix edition) wiring. `require` is memoized, so requiring the
-- implementation on each keypress is effectively free after the first hit --
-- this keeps the module out of startup while the keymap loads it on demand.
--
-- `M` toggles the full v2 session (open quickfix + line highlights, or close);
-- this shadows the native "move to middle window line" motion. `sf` toggles
-- only the changed-line highlight, independent of the session, for a quick
-- eyeball of edits against HEAD without opening the quickfix list. The
-- `:OneDiffQf` command below is an alternative entry point.

-- Toggle the v2 review session.
vim.keymap.set("n", "M", function()
  require("my_plugins.onediff_qf").toggle()
end, { desc = "Toggle OneDiff v2 (quickfix + line highlights)" })

-- Toggle only the changed-line highlight (no quickfix list), independent of
-- the session.
vim.keymap.set("n", "sf", function()
  require("my_plugins.onediff_qf").toggle_highlight()
end, { desc = "Toggle OneDiff v2 changed-line highlight" })

vim.api.nvim_create_user_command("OneDiffQf", function()
  require("my_plugins.onediff_qf").toggle()
end, { desc = "Toggle OneDiff v2 (quickfix + line highlights)" })

vim.api.nvim_create_user_command("OneDiffQfRefresh", function()
  require("my_plugins.onediff_qf").refresh()
end, { desc = "Rebuild the OneDiff v2 quickfix list" })
