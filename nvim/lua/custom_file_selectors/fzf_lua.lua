local M = {}

local root = require("custom_file_selectors.root")

local defaults = {
  -- preview.layout = "vertical": force a stacked preview in every window
  -- instead of the default "flex" (side-by-side that flips only when narrow).
  -- preview.vertical = "up:45%": preview on top, results/prompt below.
  winopts = {
    height = 0.99,
    width = 0.96,
    preview = { layout = "vertical", vertical = "up:45%" },
  },
  fzf_opts = { ["--layout"] = "default" },
}

local function with_defaults(opts)
  return vim.tbl_deep_extend("force", defaults, opts or {})
end

local function fzf()
  return require("fzf-lua")
end

function M.find_files()
  fzf().files(with_defaults({ hidden = true, cwd = root.get() }))
end

function M.find_sibling_files()
  fzf().files(with_defaults({
    cwd = vim.fn.expand("%:h"),
    rg_opts = "--files --no-ignore --hidden -g '!.git' --max-depth 1",
  }))
end

function M.find_changed_files()
  local current_buf = vim.api.nvim_get_current_buf()
  if vim.b[current_buf].is_onediff_buffer then
    local onediff = require("my_plugins.onediff")
    onediff.open_file_picker()
  else
    fzf().git_status(with_defaults({}))
  end
end

function M.find_changed_files_by_extension(extension)
  local git_cmd = vim.fn.systemlist("git status --porcelain")
  local files = {}
  for _, line in ipairs(git_cmd) do
    local file = line:sub(4)
    if file:match(extension .. "$") then
      table.insert(files, line:sub(1, 2) .. " " .. file)
    end
  end

  if #files == 0 then
    vim.notify("No changed files matching: " .. extension, vim.log.levels.INFO)
    return
  end

  fzf().fzf_exec(files, with_defaults({
    prompt = "Git Status (" .. extension .. ")> ",
    actions = {
      ["default"] = function(selected)
        if selected and selected[1] then
          local file = selected[1]:match("^%S+%s+(.+)$")
          if file then vim.cmd("edit " .. vim.fn.fnameescape(file)) end
        end
      end,
    },
    previewer = "builtin",
  }))
end

function M.find_resource_in_dir(dir)
  fzf().files(with_defaults({ cwd = dir }))
end

function M.find_files_in_dirs(dirs)
  local available = vim.tbl_filter(function(d) return d and d ~= "" and vim.fn.isdirectory(d) == 1 end, dirs)
  if #available == 0 then return end
  fzf().files(with_defaults({ cmd = "fd --type f . " .. table.concat(available, " ") }))
end

function M.find_files_in_dirs_relative(dirs)
  local available = vim.tbl_filter(function(d) return d and d ~= "" and vim.fn.isdirectory(d) == 1 end, dirs)
  if #available == 0 then return end
  local entries = {}
  for _, dir in ipairs(available) do
    for _, full_path in ipairs(vim.fn.systemlist("fd --type f . " .. dir)) do
      local relative = full_path:gsub("^" .. vim.pesc(dir) .. "/", "")
      table.insert(entries, relative .. "\t" .. full_path)
    end
  end
  fzf().fzf_exec(entries, with_defaults({
    fzf_opts = { ["--with-nth"] = "1", ["--nth"] = "1", ["--delimiter"] = "\t" },
    previewer = false,
    actions = {
      ["default"] = function(selected)
        if selected and selected[1] then
          local full_path = selected[1]:match("\t(.+)$")
          if full_path then vim.cmd("edit " .. vim.fn.fnameescape(full_path)) end
        end
      end,
    },
  }))
end

function M.oldfiles()
  fzf().oldfiles(with_defaults({ cwd_only = true }))
end

function M.buffer_fuzzy_find()
  fzf().lgrep_curbuf(with_defaults({}))
end

function M.buffer_list()
  fzf().buffers(with_defaults({}))
end

function M.live_grep()
  fzf().live_grep(with_defaults({}))
end

function M.live_grep_in_dirs(dirs)
  local available = vim.tbl_filter(function(d) return d and d ~= "" and vim.fn.isdirectory(d) == 1 end, dirs)
  if #available == 0 then return end
  fzf().live_grep(with_defaults({ search_dirs = available, prompt = table.concat(available, ", ") .. "> " }))
end

function M.open_picker_menu()
  fzf().builtin(with_defaults({}))
end

return M
