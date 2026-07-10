local M = {}

local root = require("custom_file_selectors.root")

local function fff()
  return require("fff")
end

local function fallback(action, ...)
  local ok, fzf_lua = pcall(require, "custom_file_selectors.fzf_lua")
  if ok and type(fzf_lua[action]) == "function" then
    fzf_lua[action](...)
  else
    vim.notify("fff: action '" .. action .. "' not supported and fallback unavailable", vim.log.levels.WARN)
  end
end

function M.find_files()
  local ok, f = pcall(fff)
  if ok and f.find_files then
    f.find_files({ cwd = root.get() })
  else
    fallback("find_files")
  end
end

function M.find_sibling_files()
  local ok, f = pcall(fff)
  if ok and f.find_files then
    f.find_files({ cwd = vim.fn.expand("%:h") })
  else
    fallback("find_sibling_files")
  end
end

function M.find_changed_files()
  vim.notify("fff: find_changed_files not supported, falling back", vim.log.levels.WARN)
  fallback("find_changed_files")
end

function M.find_changed_files_by_extension(extension)
  vim.notify("fff: find_changed_files_by_extension not supported, falling back", vim.log.levels.WARN)
  fallback("find_changed_files_by_extension", extension)
end

function M.find_resource_in_dir(dir)
  local ok, f = pcall(fff)
  if ok and f.find_files then
    f.find_files({ cwd = dir })
  else
    fallback("find_resource_in_dir", dir)
  end
end

function M.find_files_in_dirs(dirs)
  vim.notify("fff: find_files_in_dirs not supported, falling back", vim.log.levels.WARN)
  fallback("find_files_in_dirs", dirs)
end

function M.find_files_in_dirs_relative(dirs)
  vim.notify("fff: find_files_in_dirs_relative not supported, falling back", vim.log.levels.WARN)
  fallback("find_files_in_dirs_relative", dirs)
end

function M.buffer_fuzzy_find()
  vim.notify("fff: buffer_fuzzy_find not supported, falling back", vim.log.levels.WARN)
  fallback("buffer_fuzzy_find")
end

function M.buffer_list()
  vim.notify("fff: buffer_list not supported, falling back", vim.log.levels.WARN)
  fallback("buffer_list")
end

function M.oldfiles()
  fallback("oldfiles")
end

function M.live_grep()
  local ok, f = pcall(fff)
  if ok and f.live_grep then
    f.live_grep({})
  else
    fallback("live_grep")
  end
end

function M.live_grep_in_dirs(dirs)
  vim.notify("fff: live_grep_in_dirs not supported, falling back", vim.log.levels.WARN)
  fallback("live_grep_in_dirs", dirs)
end

function M.open_picker_menu()
  local ok, f = pcall(fff)
  if ok and f.find_files then
    f.find_files()
  else
    fallback("find_files")
  end
end

return M
