local markview = require("markview")
local commands = require("markview.commands")

-- Filetypes markview renders — where the toggle keymap is useful.
local PREVIEW_FILETYPES = { "markdown", "quarto", "rmd", "typst", "asciidoc" }

-- Debounces the resize redraw so a click-and-drag resize costs one render
-- instead of one per intermediate column.
local resize_timer = vim.uv.new_timer()
local RESIZE_DEBOUNCE_MS = 60

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

-- Re-renders every attached, preview-enabled buffer. Wrapped because the uv
-- timer fires off the main loop, where the api calls inside are not allowed.
local rerender_all = vim.schedule_wrap(commands.Render)

-- Restarts the debounce window on each resize event.
local function on_resize()
  resize_timer:stop()
  resize_timer:start(RESIZE_DEBOUNCE_MS, 0, rerender_all)
end

-- Markview computes hrule, table-border and code-block widths from the window
-- width at render time but registers no resize autocmd, so those decorations
-- keep their old width — overflowing or falling short — until an unrelated
-- event (cursor move, mode change, edit) happens to trigger a redraw.
vim.api.nvim_create_autocmd({ "VimResized", "WinResized" }, {
  callback = on_resize,
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
