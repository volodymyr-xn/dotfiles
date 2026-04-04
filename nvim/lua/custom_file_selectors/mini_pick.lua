local M = {}

local function window_config()
  return {
    height = math.floor(vim.o.lines * 0.9),
    width = math.floor(vim.o.columns * 0.9),
  }
end

local function pick()
  return require("mini.pick")
end

local win_opts = {
  window = { config = window_config },
  options = { content_from_bottom = true },
}

function M.find_files()
  pick().builtin.files({ tool = "fd" }, win_opts)
end

function M.find_sibling_files()
  pick().builtin.files({ cwd = vim.fn.expand("%:h") }, win_opts)
end

function M.find_changed_files()
  local current_buf = vim.api.nvim_get_current_buf()
  if vim.b[current_buf].is_onediff_buffer then
    local onediff = require("my_plugins.onediff")
    onediff.open_file_picker()
    return
  end

  local git_lines = vim.fn.systemlist("git status --porcelain")
  local items = {}
  for _, line in ipairs(git_lines) do
    local file = line:sub(4)
    table.insert(items, { text = line:sub(1, 2) .. " " .. file, path = file })
  end

  pick().start(vim.tbl_extend("force", win_opts, {
    source = {
      name = "Git Changed Files",
      items = items,
      choose = function(item)
        if item and item.path then
          vim.cmd("edit " .. vim.fn.fnameescape(item.path))
        end
      end,
    },
  }))
end

function M.find_changed_files_by_extension(extension)
  local git_lines = vim.fn.systemlist("git status --porcelain")
  local items = {}
  for _, line in ipairs(git_lines) do
    local file = line:sub(4)
    if file:match(extension .. "$") then
      table.insert(items, { text = line:sub(1, 2) .. " " .. file, path = file })
    end
  end

  if #items == 0 then
    vim.notify("No changed files matching: " .. extension, vim.log.levels.INFO)
    return
  end

  pick().start(vim.tbl_extend("force", win_opts, {
    source = {
      name = "Git Status (" .. extension .. ")",
      items = items,
      choose = function(item)
        if item and item.path then
          vim.cmd("edit " .. vim.fn.fnameescape(item.path))
        end
      end,
    },
  }))
end

function M.find_resource_in_dir(dir)
  pick().builtin.files({ cwd = dir }, win_opts)
end

function M.find_files_in_dirs_relative(dirs)
  local available = vim.tbl_filter(function(d) return d and d ~= "" and vim.fn.isdirectory(d) == 1 end, dirs)
  if #available == 0 then return end
  local items = {}
  for _, dir in ipairs(available) do
    for _, full_path in ipairs(vim.fn.systemlist("fd --type f . " .. dir)) do
      local relative = full_path:gsub("^" .. vim.pesc(dir) .. "/", "")
      table.insert(items, { text = relative, path = full_path })
    end
  end
  pick().start(vim.tbl_extend("force", win_opts, {
    source = {
      name = "Files",
      items = items,
      choose = function(item)
        if item and item.path then vim.cmd("edit " .. vim.fn.fnameescape(item.path)) end
      end,
    },
  }))
end

function M.find_files_in_dirs(dirs)
  local available = vim.tbl_filter(function(d) return d and d ~= "" and vim.fn.isdirectory(d) == 1 end, dirs)
  if #available == 0 then return end
  local MiniPick = pick()
  local files = vim.fn.systemlist("fd --type f . " .. table.concat(available, " "))
  local items = {}
  for _, f in ipairs(files) do
    table.insert(items, { text = f, path = f })
  end
  MiniPick.start(vim.tbl_extend("force", win_opts, {
    source = {
      name = "Files in dirs",
      items = items,
      choose = function(item)
        if item and item.path then
          vim.cmd("edit " .. vim.fn.fnameescape(item.path))
        end
      end,
    },
  }))
end

function M.oldfiles()
  local cwd = vim.fn.getcwd() .. "/"
  local seen = {}
  local items = {}

  local function add(path)
    if seen[path] or not vim.startswith(path, cwd) or vim.fn.filereadable(path) ~= 1 then return end
    seen[path] = true
    table.insert(items, { text = path:sub(#cwd + 1), path = path })
  end

  for buf = 1, vim.fn.bufnr("$") do
    if vim.fn.buflisted(buf) == 1 then
      local name = vim.fn.bufname(buf)
      if name ~= "" then add(name) end
    end
  end

  for _, f in ipairs(vim.v.oldfiles) do
    if not f:match("fugitive:") and not f:match("NERD_tree")
        and not f:match("^/tmp/") and not f:match("%.git/") then
      add(f)
    end
  end

  if #items == 0 then return end

  pick().start(vim.tbl_extend("force", win_opts, {
    source = {
      name = "Recent Files",
      items = items,
      choose = function(item)
        if item and item.path then vim.cmd("edit " .. vim.fn.fnameescape(item.path)) end
      end,
    },
  }))
end

function M.buffer_fuzzy_find()
  pick().builtin.grep({ scope = "current" }, win_opts)
end

function M.buffer_list()
  pick().builtin.buffers({}, win_opts)
end

function M.live_grep()
  pick().builtin.grep_live({}, win_opts)
end

function M.live_grep_in_dirs(dirs)
  local available = vim.tbl_filter(function(d) return d and d ~= "" and vim.fn.isdirectory(d) == 1 end, dirs)
  if #available == 0 then return end
  local MiniPick = pick()
  local show = MiniPick.config.source.show or function(buf_id, items, query)
    MiniPick.default_show(buf_id, items, query, { show_icons = true })
  end
  local process
  local match = function(_, _, query)
    pcall(vim.loop.process_kill, process)
    if #query == 0 then return MiniPick.set_picker_items({}, { do_match = false }) end
    local command = {
      "rg", "--column", "--line-number", "--no-heading",
      "--field-match-separator", "\\x00", "--color=never",
      "--smart-case", "--", table.concat(query),
    }
    vim.list_extend(command, available)
    process = MiniPick.set_picker_items_from_cli(command, { set_items_opts = { do_match = false } })
  end
  MiniPick.start(vim.tbl_extend("force", win_opts, {
    source = { name = table.concat(available, ", "), show = show, items = {}, match = match },
  }))
end

function M.open_picker_menu()
  local MiniPick = pick()
  local builtin_names = {}
  for name, _ in pairs(MiniPick.builtin) do
    table.insert(builtin_names, name)
  end
  MiniPick.start(vim.tbl_extend("force", win_opts, {
    source = {
      name = "MiniPick builtins",
      items = builtin_names,
      choose = function(item)
        if item and MiniPick.builtin[item] then
          MiniPick.builtin[item]()
        end
      end,
    },
  }))
end

return M
