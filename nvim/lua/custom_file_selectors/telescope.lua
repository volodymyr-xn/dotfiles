local M = {}

local root = require("custom_file_selectors.root")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local action_set = require("telescope.actions.set")

local function builtin()
  return require("telescope.builtin")
end

-- Label a Telescope picker with a left-aligned title on its prompt border,
-- mirroring the fzf backend's left-aligned --border-label. The {pos="NW"} title
-- table is what plenary's border renderer left-aligns ("W"); a plain string
-- would center. Merges into and returns `opts`.
local function labeled(label, opts)
  opts.prompt_title = { { text = label, pos = "NW" } }
  return opts
end

-- Picker label built from directory basenames, e.g. "javascript, components".
local function dirs_label(dirs)
  return table.concat(vim.tbl_map(function(dir) return vim.fn.fnamemodify(dir, ":t") end, dirs), ", ")
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
  builtin().find_files(labeled("Files", { previewer = false, cwd = root.get() }))
end

function M.find_sibling_files()
  local dir = vim.fn.expand("%:h")
  builtin().find_files(labeled("Sibling Files", {
    cwd = dir,
    find_command = { "rg", "--files", "--no-ignore", "--hidden", "-g", "!.git", "--max-depth", "1" },
  }))
end

function M.find_changed_files()
  builtin().git_status(labeled("Changed Files", { attach_mappings = jump_to_first_change_on_select }))
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

  local label = "Git Status (" .. extension .. ")"

  pickers.new({}, {
    prompt_title = { { text = label, pos = "NW" } },
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
  builtin().find_files(labeled(vim.fn.fnamemodify(dir, ":t"), { cwd = dir, previewer = false }))
end

function M.find_files_in_dirs(dirs)
  local available = vim.tbl_filter(function(d) return d and d ~= "" and vim.fn.isdirectory(d) == 1 end, dirs)
  if #available == 0 then return end
  builtin().find_files(labeled(dirs_label(available), { search_dirs = available, previewer = false }))
end

function M.find_files_in_dirs_relative(dirs)
  local available = vim.tbl_filter(function(d) return d and d ~= "" and vim.fn.isdirectory(d) == 1 end, dirs)
  if #available == 0 then return end
  builtin().find_files(labeled(dirs_label(available), {
    search_dirs = available,
    previewer = false,
    path_display = function(_, path)
      for _, dir in ipairs(available) do
        local stripped = path:gsub("^" .. vim.pesc(dir) .. "/", "")
        if stripped ~= path then return stripped end
      end
      return path
    end,
  }))
end

function M.oldfiles()
  builtin().oldfiles(labeled("MRU", { only_cwd = true }))
end

function M.buffer_fuzzy_find()
  builtin().current_buffer_fuzzy_find(labeled("Buffer Lines (text only)", {}))
end

function M.buffer_list()
  builtin().buffers(labeled("Buffers", {}))
end

function M.live_grep()
  builtin().live_grep(labeled("Live Grep - rg (text only)", {}))
end

function M.live_grep_in_dirs(dirs)
  local available = vim.tbl_filter(function(d) return d and d ~= "" and vim.fn.isdirectory(d) == 1 end, dirs)
  if #available == 0 then return end
  builtin().live_grep(labeled(dirs_label(available), { search_dirs = available }))
end

function M.open_picker_menu()
  builtin().builtin(labeled("Pickers", {}))
end

return M
