-- Renders the current markdown buffer to a self-contained HTML file via the
-- bin/c-md-to-html script and opens the result in the default system browser.
-- Pairs with markdown_image_preview.lua but avoids the kitty-graphics path
-- (works in any terminal, including ghostty + tmux without passthrough quirks).

local api = vim.api
local fn = vim.fn

local M = {}

-- Single shared cache path; each render overwrites the previous HTML so the
-- browser tab just needs a refresh (or auto-reloads if already open).
local HTML_PATH = fn.stdpath("cache") .. "/markdown-html-preview.html"

-- Picks the right "open this file" command per platform.
local function open_command()
  if fn.has("mac") == 1 then
    return "open"
  end
  return "xdg-open"
end

-- Async callback for vim.system; runs on the main loop after the render exits.
local function on_render_complete(obj)
  if obj.code ~= 0 then
    local stderr = (obj.stderr ~= nil and obj.stderr ~= "") and obj.stderr or "(no stderr)"
    vim.notify("markdown html preview failed:\n" .. stderr, vim.log.levels.ERROR)
    return
  end

  vim.system({ open_command(), HTML_PATH }, { detach = true })
end

-- Renders the current buffer to HTML (auto-saving first) and opens it in the browser.
function M.preview()
  local md_path = api.nvim_buf_get_name(0)
  if md_path == "" then
    vim.notify("markdown html preview: buffer has no file path — save it first", vim.log.levels.WARN)
    return
  end

  if vim.bo.modified then
    vim.cmd("silent write")
  end

  vim.notify("Rendering markdown to HTML…", vim.log.levels.INFO)

  vim.system(
    { "c-md-to-html", md_path, HTML_PATH },
    { text = true },
    function(obj) vim.schedule(function() on_render_complete(obj) end) end
  )
end

return M
