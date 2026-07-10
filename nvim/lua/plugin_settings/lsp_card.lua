-- LSP / treesitter card lazy-loader.
--
-- Same recursion-proof pattern as memory_manager: the stub calls the module
-- table directly, never `vim.cmd("LspCard")`, so a missing override can't
-- loop forever.

vim.api.nvim_create_user_command("LspCard", function()
  require("my_plugins.lsp_card").open()
end, { desc = "Open the LSP / treesitter card" })

-- `sc` — LSP clients, treesitter parsers, and per-buffer diagnostics.
vim.keymap.set("n", "sc", ":LspCard<CR>", {
  noremap = true,
  silent = true,
  desc = "Open LSP / treesitter card",
})
