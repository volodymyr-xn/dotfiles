require("markview").setup({
  preview = {
    icon_provider = "devicons",
    callbacks = {
      on_attach = function(buf)
        vim.keymap.set("n", "sw", "<cmd>Markview Toggle<CR>", { buffer = buf, silent = true })
      end,
    },
  },
  markdown = {
    list_items = {
      indent_size = 2,
      shift_width = 2,
      marker_minus = { add_padding = true, text = "●", hl = "MarkviewListItemMinus" },
      marker_plus = { add_padding = false, text = "◈", hl = "MarkviewListItemPlus" },
      marker_star = { add_padding = false, text = "◇", hl = "MarkviewListItemStar" },
    },
  },
})
