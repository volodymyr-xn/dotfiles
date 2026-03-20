local M = {}

M.defaults = {
  base_ref = "HEAD",
  picker = "telescope",
  sidebar = {
    width = 35,
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
  vim.api.nvim_set_hl(0, "OneDiffLineAdd", { bg = "#2d4a3e" })
  vim.api.nvim_set_hl(0, "OneDiffLineStaged", { bg = "#1e3a5f" })
  vim.api.nvim_set_hl(0, "OneDiffLineDelete", { bg = "#4a2d2d" })
  vim.api.nvim_set_hl(0, "OneDiffCharAdd", { bg = "#3d6a5e", bold = true })
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
