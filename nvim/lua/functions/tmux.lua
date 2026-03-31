function FocusTmuxRunner()
  vim.fn.VimuxTmux("select-pane -t " .. vim.g.VimuxRunnerIndex)
end

local AI_PROCESS_NAMES = { "claude", "agent" }

function IsTmuxRunnerAIProcess()
  if not vim.g.VimuxRunnerIndex or vim.g.VimuxRunnerIndex == "" then return false end

  local pane_pid = vim.fn.VimuxTmux("display -p -t " .. vim.g.VimuxRunnerIndex .. " '#{pane_pid}'"):gsub("%s+", "")
  local result = vim.fn.system(
    "pgrep -P " .. pane_pid ..
    " | xargs -I{} sh -c 'ps -o comm= -p {}; pgrep -P {} | xargs ps -o comm= -p 2>/dev/null'" ..
    " 2>/dev/null"
  )

  for _, name in ipairs(AI_PROCESS_NAMES) do
    if result:match(name) then return true end
  end
  return false
end

-- Scans all panes in the current tmux window for one running an AI process; sets VimuxRunnerIndex if found
function FindAndSetAITmuxPane()
  local current_pane = vim.fn.system("tmux display-message -p '#{pane_id}'"):gsub("%s+", "")
  local panes_output = vim.fn.system("tmux list-panes -F '#{pane_id} #{pane_pid}'")

  for line in panes_output:gmatch("[^\n]+") do
    local pane_id, pane_pid = line:match("(%S+)%s+(%S+)")

    if pane_id and pane_pid and pane_id ~= current_pane then
      local result = vim.fn.system(
        "pgrep -P " .. pane_pid ..
        " | xargs -I{} sh -c 'ps -o comm= -p {}; pgrep -P {} | xargs ps -o comm= -p 2>/dev/null'" ..
        " 2>/dev/null"
      )

      for _, name in ipairs(AI_PROCESS_NAMES) do
        if result:match(name) then
          vim.g.VimuxRunnerIndex = pane_id
          return true
        end
      end
    end
  end

  return false
end

-- Returns true if the current vimux runner has an AI process, or finds and sets one from all panes
function EnsureAITmuxRunner()
  if IsTmuxRunnerAIProcess() then return true end
  return FindAndSetAITmuxPane()
end

function SendFileToTmux()
  if not EnsureAITmuxRunner() then
    vim.api.nvim_echo({{"No tmux pane with AI process found", "ErrorMsg"}}, true, {})
    return
  end

  vim.fn.VimuxSendText("@" .. vim.fn.expand("%") .. " ")

  FocusTmuxRunner()
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

  if not EnsureAITmuxRunner() then
    vim.api.nvim_echo({{"No tmux pane with AI process found", "ErrorMsg"}}, true, {})
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

  SendMultilineText("@" .. vim.fn.expand("%") .. " \n```\n  " .. text .. "\n```")
  vim.fn.VimuxSendKeys("S-Enter")

  FocusTmuxRunner()
end

function SendPathToTmux(path)
  if not EnsureAITmuxRunner() then
    vim.api.nvim_echo({{"No tmux pane with AI process found", "ErrorMsg"}}, true, {})
    return
  end

  vim.fn.VimuxSendText("@" .. path .. " ")
  FocusTmuxRunner()
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

