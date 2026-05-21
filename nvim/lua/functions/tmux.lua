-- Telescope modules used by with_ai_pane() below. Required lazily inside
-- the function so this file can load at startup without forcing
-- telescope to load too (it's `cmd = "Telescope"` lazy in
-- plugins_install.lua; a module-top require would defeat that gate).

local AI_PROCESS_NAMES = { "claude", "agent" }
local PROCESS_TREE_DEPTH = 3
-- If process not found increase depth to 4 or 5
-- local PROCESS_TREE_DEPTH = 4

local NO_AI_PANE_MSG = "No tmux pane with AI process found"
local NEWLINE_KEYS = { claude = "S-Enter", agent = "C-j" }

local M = {}

-- Returns path relative to git root or cwd, whichever applies
local function relative_path(path)
  local absolute = vim.fn.resolve(vim.fn.fnamemodify(path, ":p"))
  local git_root = vim.fn.systemlist("git rev-parse --show-toplevel 2>/dev/null")[1]
  local root = (git_root and git_root ~= "" and not git_root:match("^fatal")) and git_root or vim.fn.getcwd()

  if vim.startswith(absolute, root .. "/") then
    return absolute:sub(#root + 2)
  end

  return absolute
end

-- Walks a process tree from root_pid; returns matched AI process name or nil
local function find_ai_process_name(root_pid)
  local pids = root_pid

  for _ = 1, PROCESS_TREE_DEPTH do
    local output = vim.fn.system("pgrep -P " .. pids .. " 2>/dev/null")
    local children = vim.tbl_filter(function(s) return s ~= "" end, vim.split(output, "\n"))

    if #children == 0 then return nil end

    local joined = table.concat(children, ",")
    local names = vim.fn.system("ps -o comm= -p " .. joined .. " 2>/dev/null")

    for _, name in ipairs(AI_PROCESS_NAMES) do
      if names:match(name) then return name end
    end

    pids = joined
  end

  return nil
end

-- Scans all panes in the current tmux window; returns list of { pane_id, name, index, order }
local function find_ai_panes()
  local panes_output = vim.fn.system(
    "tmux list-panes -F '#{pane_id} #{pane_pid} #{pane_index} #{pane_active}'"
  )
  local matches = {}

  for line in panes_output:gmatch("[^\n]+") do
    local pane_id, pane_pid, pane_index, active = line:match("(%S+)%s+(%S+)%s+(%S+)%s+(%S+)")

    if pane_id and active ~= "1" then
      local name = find_ai_process_name(pane_pid)

      if name then
        table.insert(matches, {
          pane_id = pane_id, name = name, index = pane_index, order = #matches + 1,
        })
      end
    end
  end

  return matches
end

local function make_pane_entry(pane)
  local display = string.format("%d. %s (pane %s)", pane.order, pane.name, pane.index)
  return { value = pane, display = display, ordinal = display }
end

local function with_ai_pane(callback)
  local panes = find_ai_panes()

  if #panes == 0 then
    vim.api.nvim_echo({{NO_AI_PANE_MSG, "ErrorMsg"}}, true, {})
    return
  end

  if #panes == 1 then
    callback(panes[1])
    return
  end

  -- Lazy telescope load: only reached when we actually need to render
  -- the picker (2+ AI panes). Keeps telescope off the startup path.
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local themes = require("telescope.themes")

  local function select_by_number(prompt_bufnr, index)
    actions.close(prompt_bufnr)
    callback(panes[index])
  end

  local function select_entry(prompt_bufnr)
    local entry = action_state.get_selected_entry()
    actions.close(prompt_bufnr)
    if entry then callback(entry.value) end
  end

  local function attach_picker_mappings(prompt_bufnr, map)
    for i = 1, math.min(9, #panes) do
      map({ "i", "n" }, tostring(i), function()
        select_by_number(prompt_bufnr, i)
      end)
    end

    actions.select_default:replace(function()
      select_entry(prompt_bufnr)
    end)

    return true
  end

  pickers.new(themes.get_dropdown({}), {
    prompt_title = "Select AI process",
    finder = finders.new_table({
      results = panes,
      entry_maker = make_pane_entry,
    }),
    attach_mappings = attach_picker_mappings,
  }):find()
end

local function focus_pane(pane_id)
  vim.fn.system("tmux select-pane -t " .. pane_id)
end

local function send_to_pane(pane_id, text)
  vim.g.VimuxRunnerIndex = pane_id
  vim.fn.VimuxSendText(text)
end

local function send_multiline_text(pane_id, text, process_name)
  vim.g.VimuxRunnerIndex = pane_id
  local newline_key = NEWLINE_KEYS[process_name] or "S-Enter"
  local lines = vim.split(text, "\n", { plain = true })

  for i, line in ipairs(lines) do
    if line ~= "" then
      vim.fn.VimuxSendText(line)
    end

    if i < #lines then
      vim.fn.VimuxSendKeys(newline_key)
    end
  end
end

-- Strips the shared leading whitespace from a list of lines
local function dedent_lines(lines)
  local min_indent = math.huge

  for _, line in ipairs(lines) do
    if line:match("%S") then
      local indent = #line:match("^(%s*)")
      if indent < min_indent then min_indent = indent end
    end
  end

  if min_indent == math.huge then min_indent = 0 end

  local result = {}

  for _, line in ipairs(lines) do
    table.insert(result, line:sub(min_indent + 1))
  end

  return result
end

function M.send_file()
  local file = relative_path(vim.fn.expand("%:p"))

  local function handler(pane)
    send_to_pane(pane.pane_id, "@" .. file .. " ")
    focus_pane(pane.pane_id)
  end

  with_ai_pane(handler)
end

function M.send_selection()
  local mode = vim.fn.mode()

  if mode ~= "v" and mode ~= "V" then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)
    vim.notify("Visual-block mode not supported", vim.log.levels.WARN)
    return
  end

  local start_pos = vim.fn.getpos("v")
  local end_pos = vim.fn.getpos(".")

  local start_line = start_pos[2]
  local start_col = start_pos[3]
  local end_line = end_pos[2]
  local end_col = end_pos[3]

  if start_line > end_line or (start_line == end_line and start_col > end_col) then
    start_line, end_line = end_line, start_line
    start_col, end_col = end_col, start_col
  end

  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)

  local text

  if mode == "v" then
    local all_lines = vim.fn.getline(start_line, end_line)
    all_lines[#all_lines] = all_lines[#all_lines]:sub(1, end_col)
    all_lines[1] = all_lines[1]:sub(start_col)
    text = table.concat(dedent_lines(all_lines), "\n")
  else
    local lines = dedent_lines(vim.fn.getline(start_line, end_line))
    text = table.concat(lines, "\n")
  end

  local file = relative_path(vim.fn.expand("%:p"))
  -- Append :line for single line, or #Lstart-end range for multiline
  local file_ref = (start_line == end_line)
    and (file .. ":" .. start_line)
    or (file .. "#L" .. start_line .. "-" .. end_line)

  local function handler(pane)
    local indented = text:gsub("([^\n]+)", "  %1")
    send_multiline_text(pane.pane_id, "@" .. file_ref .. " \n```\n" .. indented .. "\n```", pane.name)
    vim.fn.VimuxSendKeys(NEWLINE_KEYS[pane.name] or "S-Enter")
    focus_pane(pane.pane_id)
  end

  with_ai_pane(handler)
end

function M.send_path(path)
  local relative = relative_path(path)

  local function handler(pane)
    send_to_pane(pane.pane_id, "@" .. relative .. " ")
    focus_pane(pane.pane_id)
  end

  with_ai_pane(handler)
end


return M
