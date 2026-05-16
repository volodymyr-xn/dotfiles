local M = {}

-- Fallback editor background used when `Normal` has no resolvable bg (e.g. transparent terminal).
local DEFAULT_BG = "#1e1e2e"

-- Parse a "#rrggbb" string into r, g, b integers.
local function hex_to_rgb(hex)
  return tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16)
end

-- Format r, g, b integers back into a "#rrggbb" string.
local function rgb_to_hex(r, g, b)
  return string.format("#%02x%02x%02x", r, g, b)
end

-- Resolve the current editor background color, falling back to DEFAULT_BG.
local function normal_bg()
  local hl = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
  if hl and hl.bg then
    return string.format("#%06x", hl.bg)
  end
  return DEFAULT_BG
end

-- Blend `fg_hex` over `bg_hex` at `alpha` (0..1) to fake transparency for buffer line highlights.
local function blend(fg_hex, bg_hex, alpha)
  local fr, fg, fb = hex_to_rgb(fg_hex)
  local br, bg, bb = hex_to_rgb(bg_hex)
  local mix = function(f, b) return math.floor(f * alpha + b * (1 - alpha) + 0.5) end
  return rgb_to_hex(mix(fr, br), mix(fg, bg), mix(fb, bb))
end

M.defaults = {
  base_ref = "HEAD",
  picker = "telescope",
  -- When true, attach treesitter for syntax highlighting; otherwise use Vim's built-in `:syntax`.
  use_treesitter = false,
  sidebar = {
    max_width = 45,
    min_width = 20,
    position = "left",
  },
  icons = {
    added = "+",
    deleted = "-",
    modified = "~",
    renamed = "→",
    folder_open = "▼",
    folder_closed = "▶",
  },
  highlights = {
    line_add = "OneDiffLineAdd",
    line_staged = "OneDiffLineStaged",
    line_delete = "OneDiffLineDelete",
    char_add = "OneDiffCharAdd",
    char_delete = "OneDiffCharDelete",
    sidebar_file = "OneDiffSidebarFile",
    sidebar_folder = "OneDiffSidebarFolder",
    sidebar_added = "OneDiffSidebarAdded",
    sidebar_deleted = "OneDiffSidebarDeleted",
    sidebar_modified = "OneDiffSidebarModified",
    sidebar_selected = "OneDiffSidebarSelected",
  },
  keymaps = {
    sidebar = {
      select = "<CR>",
      close = "q",
      refresh = "R",
    },
  },
}

M.current = vim.deepcopy(M.defaults)

M.namespace_id = nil

function M.apply(opts)
  M.current = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
  M.namespace_id = vim.api.nvim_create_namespace("onediff")
  M.setup_highlights()
end

function M.setup_highlights()
  -- Simulated transparency: pre-blend the original diff colors over Normal's bg
  -- since Neovim's `blend` attribute does not apply to buffer line highlights.
  local bg = normal_bg()
  local line_add_alpha = 0.45
  local char_add_alpha = 0.65
  vim.api.nvim_set_hl(0, "OneDiffLineAdd", { bg = blend("#2d4a3e", bg, line_add_alpha) })
  vim.api.nvim_set_hl(0, "OneDiffLineStaged", { bg = "#1e3a5f" })
  vim.api.nvim_set_hl(0, "OneDiffLineDelete", { bg = "#4a2d2d" })
  vim.api.nvim_set_hl(0, "OneDiffCharAdd", { bg = blend("#3d6a5e", bg, char_add_alpha), bold = true })
  vim.api.nvim_set_hl(0, "OneDiffCharDelete", { bg = "#6a3d3d", bold = true })
  vim.api.nvim_set_hl(0, "OneDiffSidebarFile", { link = "Normal", default = true })
  vim.api.nvim_set_hl(0, "OneDiffSidebarFolder", { link = "Directory", default = true })
  vim.api.nvim_set_hl(0, "OneDiffSidebarAdded", { fg = "#a6e3a1", default = true })
  vim.api.nvim_set_hl(0, "OneDiffSidebarDeleted", { fg = "#f38ba8", default = true })
  vim.api.nvim_set_hl(0, "OneDiffSidebarModified", { fg = "#f9e2af", default = true })
  vim.api.nvim_set_hl(0, "OneDiffSidebarSelected", { bg = "#45475a", bold = true, default = true })
end

function M.get(key)
  local keys = vim.split(key, ".", { plain = true })
  local value = M.current
  for _, k in ipairs(keys) do
    if value[k] then
      value = value[k]
    else
      return nil
    end
  end
  return value
end

function M.get_ns()
  if not M.namespace_id then
    M.namespace_id = vim.api.nvim_create_namespace("onediff")
  end
  return M.namespace_id
end

return M
