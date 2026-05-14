-- Wires the :MarkdownHtmlPreview command and the buffer-local `sh` keymap
-- (markdown filetype only) to my_plugins.markdown_html_preview.

local preview = require("my_plugins.markdown_html_preview")

vim.api.nvim_create_user_command(
  "MarkdownHtmlPreview",
  preview.preview,
  { desc = "Render current markdown buffer to HTML and open it in the default browser" }
)

-- Binds `sh` inside markdown buffers — matches the `sm`/`sa`/`sr` convention.
local function bind_markdown_keys(args)
  vim.keymap.set("n", "sh", preview.preview, {
    buffer = args.buf,
    silent = true,
    desc = "Markdown HTML preview (render to HTML, open in browser)",
  })
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown" },
  callback = bind_markdown_keys,
})
