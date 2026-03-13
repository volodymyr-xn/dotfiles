local M = {}

local function fff()
  return require("fff")
end

local function fallback(action, ...)
  local ok, fzf_lua = pcall(require, "my_extensions.pickers.fzf_lua")
  if ok and type(fzf_lua[action]) == "function" then
    fzf_lua[action](...)
  else
    vim.notify("fff: action '" .. action .. "' not supported and fallback unavailable", vim.log.levels.WARN)
  end
end

function M.find_files()
  local ok, f = pcall(fff)
  if ok and f.files then
    f.files()
  else
    fallback("find_files")
  end
end

function M.find_sibling_files()
  local ok, f = pcall(fff)
  if ok and f.files then
    f.files({ cwd = vim.fn.expand("%:h") })
  else
    fallback("find_sibling_files")
  end
end

function M.find_changed_files()
  local current_buf = vim.api.nvim_get_current_buf()
  if vim.b[current_buf].is_onediff_buffer then
    local onediff = require("my_extensions.onediff")
    onediff.open_file_picker()
    return
  end
  vim.notify("fff: find_changed_files not supported, falling back", vim.log.levels.WARN)
  fallback("find_changed_files")
end

function M.find_changed_files_by_extension(extension)
  vim.notify("fff: find_changed_files_by_extension not supported, falling back", vim.log.levels.WARN)
  fallback("find_changed_files_by_extension", extension)
end

function M.find_resource_in_dir(dir)
  local ok, f = pcall(fff)
  if ok and f.files then
    f.files({ cwd = dir })
  else
    fallback("find_resource_in_dir", dir)
  end
end

function M.find_files_in_dirs(dirs)
  fallback("find_files_in_dirs", dirs)
end

function M.find_files_in_dirs_relative(dirs)
  fallback("find_files_in_dirs_relative", dirs)
end

function M.buffer_fuzzy_find()
  vim.notify("fff: buffer_fuzzy_find not supported, falling back", vim.log.levels.WARN)
  fallback("buffer_fuzzy_find")
end

function M.buffer_list()
  local ok, f = pcall(fff)
  if ok and f.buffers then
    f.buffers()
  else
    fallback("buffer_list")
  end
end

function M.live_grep()
  vim.notify("fff: live_grep not supported, falling back", vim.log.levels.WARN)
  fallback("live_grep")
end

function M.open_picker_menu()
  local ok, f = pcall(fff)
  if ok and f.files then
    f.files()
  else
    fallback("find_files")
  end
end

return M
