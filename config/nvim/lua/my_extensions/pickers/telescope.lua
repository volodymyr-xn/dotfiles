local M = {}

local function builtin()
  return require("telescope.builtin")
end

function M.find_files()
  builtin().find_files({ previewer = false })
end

function M.find_sibling_files()
  builtin().find_files({
    cwd = vim.fn.expand("%:h"),
    find_command = { "rg", "--files", "--no-ignore", "--hidden", "-g", "!.git", "--max-depth", "1" },
  })
end

function M.find_changed_files()
  local current_buf = vim.api.nvim_get_current_buf()
  if vim.b[current_buf].is_onediff_buffer then
    local onediff = require("my_extensions.onediff")
    onediff.open_file_picker()
  else
    builtin().git_status()
  end
end

function M.find_changed_files_by_extension(extension)
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values

  local git_cmd = vim.fn.systemlist("git status --porcelain")
  local files = {}

  for _, line in ipairs(git_cmd) do
    local file = line:sub(4)
    if file:match(extension .. "$") then
      table.insert(files, {
        value = file,
        display = line:sub(1, 2) .. " " .. file,
        ordinal = file,
        path = file,
      })
    end
  end

  pickers.new({}, {
    prompt_title = "Git Status (" .. extension .. ")",
    finder = finders.new_table({
      results = files,
      entry_maker = function(entry)
        return entry
      end,
    }),
    sorter = conf.generic_sorter({}),
    previewer = conf.file_previewer({}),
  }):find()
end

function M.find_resource_in_dir(dir)
  builtin().find_files({ cwd = dir, previewer = false })
end

function M.find_files_in_dirs(dirs)
  local available = vim.tbl_filter(function(d) return d and d ~= "" and vim.fn.isdirectory(d) == 1 end, dirs)
  if #available == 0 then return end
  builtin().find_files({ search_dirs = available, previewer = false })
end

function M.find_files_in_dirs_relative(dirs)
  local available = vim.tbl_filter(function(d) return d and d ~= "" and vim.fn.isdirectory(d) == 1 end, dirs)
  if #available == 0 then return end
  builtin().find_files({
    search_dirs = available,
    previewer = false,
    path_display = function(_, path)
      for _, dir in ipairs(available) do
        local stripped = path:gsub("^" .. vim.pesc(dir) .. "/", "")
        if stripped ~= path then return stripped end
      end
      return path
    end,
  })
end

function M.buffer_fuzzy_find()
  builtin().current_buffer_fuzzy_find()
end

function M.buffer_list()
  builtin().buffers()
end

function M.live_grep()
  builtin().live_grep()
end

function M.open_picker_menu()
  builtin().builtin()
end

return M
