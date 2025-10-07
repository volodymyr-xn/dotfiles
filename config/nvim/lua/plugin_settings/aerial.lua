require("aerial").setup({
  -- optionally use on_attach to set keymaps when aerial has attached to a buffer
  on_attach = function(bufnr)
    -- Jump forwards/backwards with '{' and '}'
    vim.keymap.set("n", "{", "<cmd>AerialPrev<CR>", { buffer = bufnr })
    vim.keymap.set("n", "}", "<cmd>AerialNext<CR>", { buffer = bufnr })
  end,

  keymaps = {
    ["o"] = "actions.scroll",
    ["l"] = "actions.scroll",
  },

})


-- vim.keymap.set("n", "<leader>a", "<cmd>AerialToggle!<CR>")

require("leap")

vim.keymap.set({'n', 'x', 'o'}, '<leader>a', '<Plug>(leap)')
