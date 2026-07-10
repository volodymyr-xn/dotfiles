-- Shortcuts float lazy-loader.
--
-- Registers `:Shortcuts` and `s?`; the float itself (keymap collection +
-- renderer) is only required on first use.

vim.api.nvim_create_user_command("Shortcuts", function()
  require("my_plugins.shortcuts").open()
end, { desc = "Open the shortcuts float" })

-- `s?` — every keymap in this nvim, grouped by defining file / prefix / mode.
vim.keymap.set("n", "s?", ":Shortcuts<CR>", {
  noremap = true,
  silent = true,
  desc = "Open shortcuts float",
})
