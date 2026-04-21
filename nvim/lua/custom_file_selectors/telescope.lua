local M = {}

local root = require("custom_file_selectors.root")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local action_set = require("telescope.actions.set")

local function builtin()
  return require("telescope.builtin")
end

-- Returns the 1-based line number of the first changed/added hunk in `path`,
-- or nil if there are no tracked changes (e.g. untracked or unmodified files).
local function git_first_change_line(path)
  if not path or path == "" then return nil end
  local diff = vim.fn.systemlist({
    "git", "diff", "HEAD", "-U0", "--no-color", "--", path,
  })
  if vim.v.shell_error ~= 0 then return nil end
  for _, line in ipairs(diff) do
    local start = line:match("^@@ %-%d+,?%d* %+(%d+)")
    if start then
      local n = tonumber(start)
      if n and n > 0 then return n end
      return 1
    end
  end
  return nil
end

-- Focuses an existing window (across all tabs) showing `abs_path`; returns
-- true if a matching window was found and activated.
local function focus_existing_window(abs_path)
  local bufnr = vim.fn.bufnr(abs_path)
  if bufnr == -1 then return false end
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
      if vim.api.nvim_win_get_buf(win) == bufnr then
        vim.api.nvim_set_current_tabpage(tab)
        vim.api.nvim_set_current_win(win)
        return true
      end
    end
  end
  return false
end

local OPEN_CMDS = { default = "edit", horizontal = "split", vertical = "vsplit", tab = "tabedit" }

-- Replaces telescope's `select` for git_status so that an already-open file is
-- focused in its existing window/tab instead of being opened again, then the
-- cursor jumps to the file's first changed line.
local function jump_to_first_change_on_select(_, _)
  action_set.select:replace(function(prompt_bufnr, open_type)
    local entry = action_state.get_selected_entry()
    actions.close(prompt_bufnr)
    if not entry then return end
    local path = entry.path or entry.value
    if not path or path == "" then return end
    local abs_path = vim.fn.fnamemodify(path, ":p")
    if not focus_existing_window(abs_path) then
      local cmd = OPEN_CMDS[open_type] or "edit"
      vim.cmd(cmd .. " " .. vim.fn.fnameescape(abs_path))
    end
    local line = git_first_change_line(abs_path)
    if not line then return end
    pcall(vim.api.nvim_win_set_cursor, 0, { line, 0 })
    vim.cmd("normal! zz")
  end)
  return true
end

function M.find_files()
  builtin().find_files({ previewer = false, cwd = root.get() })
end

function M.find_sibling_files()
  local dir = vim.fn.expand("%:h")
  builtin().find_files({
    cwd = dir,
    prompt_title = dir,
    find_command = { "rg", "--files", "--no-ignore", "--hidden", "-g", "!.git", "--max-depth", "1" },
  })
end

function M.find_changed_files()
  local current_buf = vim.api.nvim_get_current_buf()
  if vim.b[current_buf].is_onediff_buffer then
    local onediff = require("my_plugins.onediff")
    onediff.open_file_picker()
  else
    builtin().git_status({ attach_mappings = jump_to_first_change_on_select })
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
  builtin().find_files({ cwd = dir, previewer = false, prompt_title = dir })
end

function M.find_files_in_dirs(dirs)
  local available = vim.tbl_filter(function(d) return d and d ~= "" and vim.fn.isdirectory(d) == 1 end, dirs)
  if #available == 0 then return end
  builtin().find_files({ search_dirs = available, previewer = false, prompt_title = table.concat(available, ", ") })
end

function M.find_files_in_dirs_relative(dirs)
  local available = vim.tbl_filter(function(d) return d and d ~= "" and vim.fn.isdirectory(d) == 1 end, dirs)
  if #available == 0 then return end
  builtin().find_files({
    search_dirs = available,
    previewer = false,
    prompt_title = table.concat(available, ", "),
    path_display = function(_, path)
      for _, dir in ipairs(available) do
        local stripped = path:gsub("^" .. vim.pesc(dir) .. "/", "")
        if stripped ~= path then return stripped end
      end
      return path
    end,
  })
end

function M.oldfiles()
  builtin().oldfiles({ only_cwd = true })
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

function M.live_grep_in_dirs(dirs)
  local available = vim.tbl_filter(function(d) return d and d ~= "" and vim.fn.isdirectory(d) == 1 end, dirs)
  if #available == 0 then return end
  builtin().live_grep({ search_dirs = available, prompt_title = table.concat(available, ", ") })
end

function M.open_picker_menu()
  builtin().builtin()
end

return M
