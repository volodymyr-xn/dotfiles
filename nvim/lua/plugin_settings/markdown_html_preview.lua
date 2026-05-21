-- Markdown HTML preview lazy-loader — defers requiring
-- `my_plugins.markdown_html_preview` until the user actually runs the
-- preview (via `:MarkdownHtmlPreview` or the `sh` keymap in markdown
-- buffers). The require runs at most once per session.

local preview_module = nil

local function preview_call()
  preview_module = preview_module or require("my_plugins.markdown_html_preview")
  preview_module.preview()
end

vim.api.nvim_create_user_command("MarkdownHtmlPreview", preview_call, {
  desc = "Render current markdown buffer to HTML and open it in the default browser",
})

-- Binds `sh` inside markdown buffers — matches the `sm`/`sa`/`sr`
-- convention; callback stays lazy until first press.
local function bind_markdown_keys(args)
  vim.keymap.set("n", "sh", preview_call, {
    buffer = args.buf,
    silent = true,
    desc = "Markdown HTML preview (render to HTML, open in browser)",
  })
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown" },
  callback = bind_markdown_keys,
})
