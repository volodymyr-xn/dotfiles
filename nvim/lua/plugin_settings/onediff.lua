-- OneDiff settings + wiring. The settings module is required eagerly (a plain
-- table, no gitsigns dependency) while the implementation stays behind the
-- keymaps: `require` is memoized, so requiring it on each keypress is
-- effectively free after the first hit -- this keeps the heavy module out of
-- startup, and out of gitsigns' load order.
--
-- `M` toggles the full review session (open quickfix + line highlights, or
-- close); this shadows the native "move to middle window line" motion. `sf`
-- turns on (and re-diffs) only the changed-line highlight, independent of the
-- session, for a quick eyeball of edits against HEAD without opening the
-- quickfix list. The `:OneDiff` command below is an alternative entry point.

require("my_plugins.onediff.config").setup({
  -- Inline deleted-line virtual lines from session start (`<C-S-M>` flips).
  -- show_deleted = false,
  show_deleted = true,

  -- Quickfix layout: "bottom" (full-width split) or "right" / "left" (sidebar
  -- `width` columns wide, entries rendered without the changed line's text).
  position = "left",
  width = 60,
})

-- Load the implementation on first use. `require` is memoized, so every call
-- after the first is a plain table lookup.
local function onediff()
  return require("my_plugins.onediff")
end

local TOGGLE_DESC = "Toggle OneDiff (quickfix + line highlights)"

-- Toggle the review session.
vim.keymap.set("n", "M", function()
  onediff().toggle()
end, { desc = TOGGLE_DESC })

-- Show / re-diff only the changed-line highlight (no quickfix list),
-- independent of the session.
vim.keymap.set("n", "sf", function()
  onediff().refresh_highlight()
end, { desc = "Refresh OneDiff changed-line highlight" })

vim.api.nvim_create_user_command("OneDiff", function()
  onediff().toggle()
end, { desc = TOGGLE_DESC })

vim.api.nvim_create_user_command("OneDiffRefresh", function()
  onediff().refresh()
end, { desc = "Rebuild the OneDiff quickfix list" })
