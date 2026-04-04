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

-- Checks if a process tree contains an AI process name
local function has_ai_process(pid)
  local result = collect_descendant_names(pid)

  for _, name in ipairs(AI_PROCESS_NAMES) do
    if result:match(name) then return true end
  end

  return false
end

-- Scans all panes in the current tmux window for one running an AI process; returns pane_id or nil
local function find_ai_pane()
  local current_pane = vim.fn.system("tmux display-message -p '#{pane_id}'"):gsub("%s+", "")
  local panes_output = vim.fn.system("tmux list-panes -F '#{pane_id} #{pane_pid}'")

  for line in panes_output:gmatch("[^\n]+") do
    local pane_id, pane_pid = line:match("(%S+)%s+(%S+)")

    if pane_id and pane_pid and pane_id ~= current_pane then
      if has_ai_process(pane_pid) then return pane_id end
    end
  end

  return nil
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

-- Sends multiline text to tmux by splitting on newlines and using S-Enter as line separator,
-- so TUI inputs (e.g. Claude Code) receive proper newlines instead of submit events.
local function SendMultilineText(text)
  local lines = vim.split(text, "\n", { plain = true })

  for i, line in ipairs(lines) do
    if line ~= "" then
      vim.fn.VimuxSendText(line)
    end

    if i < #lines then
      vim.fn.VimuxSendKeys("S-Enter")
    end
  end
end

function SendFileToTmux()
  local pane_id = find_ai_pane()

  if not pane_id then
    vim.api.nvim_echo({{NO_AI_PANE_MSG, "ErrorMsg"}}, true, {})
    return
  end

  send_to_pane(pane_id, "@" .. vim.fn.expand("%") .. " ")
  focus_pane(pane_id)
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

  local pane_id = find_ai_pane()

  if not pane_id then
    vim.api.nvim_echo({{NO_AI_PANE_MSG, "ErrorMsg"}}, true, {})
    return
  end

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

  vim.g.VimuxRunnerIndex = pane_id
  SendMultilineText("@" .. vim.fn.expand("%") .. " \n```\n  " .. text .. "\n```")
  vim.fn.VimuxSendKeys("S-Enter")

  focus_pane(pane_id)
end

function SendPathToTmux(path)
  local pane_id = find_ai_pane()

  if not pane_id then
    vim.api.nvim_echo({{NO_AI_PANE_MSG, "ErrorMsg"}}, true, {})
    return
  end

  send_to_pane(pane_id, "@" .. path .. " ")
  focus_pane(pane_id)
end

