require("aerial").setup({
  -- Determines how the aerial window decides which buffer to display symbols for
  --   window - aerial window will display symbols for the buffer in the window from which it was opened
  --   global - aerial window will display symbols for the current window
  attach_mode = "global",
  -- backends = { "treesitter", "lsp", "markdown", "asciidoc", "man" },
  backends = { "lsp", "treesitter", "markdown", "asciidoc", "man" },

  filter_kind = {
    "Class",
    "Method",
    "Field",
    "Property",
    -- "Variable"
  },

  icons = {
    Class = "𝓒",
    Method = "ƒ",
    Function = "ƒ",
    -- Variable = "",
    -- Field = "",
    Property = "",
  },

  -- optionally use on_attach to set keymaps when aerial has attached to a buffer
  on_attach = function(bufnr)
    -- Jump forwards/backwards with '{' and '}'
    vim.keymap.set("n", "]", "<cmd>AerialPrev<CR>", { buffer = bufnr, desc = "Previous aerial item" })
    vim.keymap.set("n", "[", "<cmd>AerialNext<CR>", { buffer = bufnr, desc = "Next aerial item" })
  end,

  keymaps = {
    ["o"] = "actions.scroll",
    ["l"] = "actions.scroll",
  },
})

vim.api.nvim_set_hl(0, "AerialLine", { fg = "#a6da95", bg = "#2e3245" })

-- require("leap")
-- vim.keymap.set({'n', 'x', 'o'}, '<leader>a', '<Plug>(leap)')
