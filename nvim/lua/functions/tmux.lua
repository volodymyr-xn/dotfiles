local AI_PROCESS_NAMES = { "claude", "agent" }
local PROCESS_TREE_DEPTH = 4
local NO_AI_PANE_MSG = "No tmux pane with AI process found"

-- Collects process names from a PID's descendant tree up to PROCESS_TREE_DEPTH levels
local function collect_descendant_names(pid)
  local cmd = string.format(
    "pids=%s; for i in $(seq 1 %d); do pids=$(echo \"$pids\" | xargs -I{} pgrep -P {} 2>/dev/null);"
    .. " [ -z \"$pids\" ] && break; echo \"$pids\" | xargs ps -o comm= -p 2>/dev/null; done",
    pid, PROCESS_TREE_DEPTH
  )

  return vim.fn.system(cmd)
end

-- Returns the matched AI process name from a PID's descendant tree, or nil
local function find_ai_process_name(pid)
  local result = collect_descendant_names(pid)

  for _, name in ipairs(AI_PROCESS_NAMES) do
    if result:match(name) then return name end
  end

  return nil
end

-- Scans all panes in the current tmux window; returns list of { pane_id, process_name }
local function find_ai_panes()
  local current_pane = vim.fn.system("tmux display-message -p '#{pane_id}'"):gsub("%s+", "")
  local panes_output = vim.fn.system("tmux list-panes -F '#{pane_id} #{pane_pid} #{pane_index}'")
  local matches = {}

  for line in panes_output:gmatch("[^\n]+") do
    local pane_id, pane_pid, pane_index = line:match("(%S+)%s+(%S+)%s+(%S+)")

    if pane_id and pane_pid and pane_id ~= current_pane then
      local process_name = find_ai_process_name(pane_pid)

      if process_name then
        table.insert(matches, { pane_id = pane_id, name = process_name, index = pane_index })
      end
    end
  end

  return matches
end

-- Resolves a single AI pane, showing a picker if multiple found; calls callback(pane)
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

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  pickers.new(require("telescope.themes").get_dropdown({}), {
    prompt_title = "Select AI process",
    finder = finders.new_table({
      results = panes,
      entry_maker = function(pane)
        local idx = 0

        for i, p in ipairs(panes) do
          if p.pane_id == pane.pane_id then idx = i; break end
        end

        local display = string.format("%d. %s (pane %s)", idx, pane.name, pane.index)
        return { value = pane, display = display, ordinal = display }
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      -- Pressing 1-9 instantly selects the corresponding entry
      for i = 1, math.min(9, #panes) do
        map({ "i", "n" }, tostring(i), function()
          actions.close(prompt_bufnr)
          callback(panes[i])
        end)
      end

      actions.select_default:replace(function()
        local entry = action_state.get_selected_entry()
        actions.close(prompt_bufnr)

        if entry then callback(entry.value) end
      end)

      return true
    end,
  }):find()
end

-- Focuses a tmux pane by id
local function focus_pane(pane_id)
  vim.fn.system("tmux select-pane -t " .. pane_id)
end

-- Sends text to a tmux pane via VimuxSendText, setting the runner index temporarily
local function send_to_pane(pane_id, text)
  vim.g.VimuxRunnerIndex = pane_id
  vim.fn.VimuxSendText(text)
end

-- Newline key per AI process: S-Enter for Claude, C-j for Cursor agent
local NEWLINE_KEYS = { claude = "S-Enter", agent = "C-j" }

-- Sends multiline text to tmux, using process-specific key for newlines
local function send_multiline_text(text, process_name)
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

function SendFileToTmux()
  local file = vim.fn.expand("%")

  with_ai_pane(function(pane)
    send_to_pane(pane.pane_id, "@" .. file .. " ")
    focus_pane(pane.pane_id)
  end)
end

function DedentLines(lines)
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

function SendSelectionToTmux()
  local mode = vim.fn.mode()
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
    text = table.concat(DedentLines(all_lines), "\n")
  else
    local lines = DedentLines(vim.fn.getline(start_line, end_line))
    text = table.concat(lines, "\n")
  end

  local file = vim.fn.expand("%")

  with_ai_pane(function(pane)
    vim.g.VimuxRunnerIndex = pane.pane_id
    send_multiline_text("@" .. file .. " \n```\n  " .. text .. "\n```", pane.name)
    vim.fn.VimuxSendKeys(NEWLINE_KEYS[pane.name] or "S-Enter")
    focus_pane(pane.pane_id)
  end)
end

function SendPathToTmux(path)
  with_ai_pane(function(pane)
    send_to_pane(pane.pane_id, "@" .. path .. " ")
    focus_pane(pane.pane_id)
  end)
end

