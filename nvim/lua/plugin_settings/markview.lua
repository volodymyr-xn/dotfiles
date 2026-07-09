local markview = require("markview")

-- Filetypes markview renders — where the toggle keymap is useful.
local PREVIEW_FILETYPES = { "markdown", "quarto", "rmd", "typst", "asciidoc" }

-- Binds `sw` to toggle markview rendering in the given buffer.
local function bind_toggle_key(buf)
  vim.keymap.set("n", "sw", "<cmd>Markview Toggle<CR>", { buffer = buf, silent = true })
end

markview.setup({
  preview = {
    icon_provider = "devicons",
  },
  markdown = {
    headings = {
      shift_width = 0,
      org_indent = true,
      org_shift_width = 2,
      org_shift_char = " ",
      org_indent_wrap = true,
    },
    list_items = {
      indent_size = 2,
      shift_width = 2,
      marker_minus = { add_padding = true, text = "●", hl = "MarkviewListItemMinus" },
      marker_plus = { add_padding = false, text = "◈", hl = "MarkviewListItemPlus" },
      marker_star = { add_padding = false, text = "◇", hl = "MarkviewListItemStar" },
    },
  },
})

-- Bind `sw` from FileType rather than markview's on_attach, so it exists
-- regardless of whether markview has attached yet (avoids the lazy-load race).
vim.api.nvim_create_autocmd("FileType", {
  pattern = PREVIEW_FILETYPES,
  callback = function(args) bind_toggle_key(args.buf) end,
})

-- The FileType event for the buffer that lazy-loaded markview already fired,
-- so bind the current buffer directly.
bind_toggle_key(vim.api.nvim_get_current_buf())
