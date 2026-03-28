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

function SendFileToTmux()
  vim.fn.VimuxOpenRunner()

  if not IsTmuxRunnerAIProcess() then
    vim.api.nvim_echo({{"Tmux runner pane has no AI process running", "ErrorMsg"}}, true, {})
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

  vim.fn.VimuxOpenRunner()

  if not IsTmuxRunnerAIProcess() then
    vim.api.nvim_echo({{"Tmux runner pane has no AI process running", "ErrorMsg"}}, true, {})
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

  vim.fn.VimuxSendText("@" .. vim.fn.expand("%") .. " :\n```\n" .. text .. "\n```\n")
  vim.fn.VimuxSendKeys("S-Enter")

  FocusTmuxRunner()
end

function SendPathToTmux(path)
  vim.fn.VimuxOpenRunner()

  if not IsTmuxRunnerAIProcess() then
    vim.api.nvim_echo({{"Tmux runner pane has no AI process running", "ErrorMsg"}}, true, {})
    return
  end

  vim.fn.VimuxSendText("@" .. path .. " ")
  FocusTmuxRunner()
end

function SendGitDiffToTmux()
  local filepath = vim.fn.expand("%")
  local diff = vim.fn.system("git diff -- " .. vim.fn.shellescape(filepath))

  if vim.v.shell_error ~= 0 or diff == "" then
    vim.api.nvim_echo({{"No git diff for current file", "WarningMsg"}}, true, {})
    return
  end

  vim.fn.VimuxOpenRunner()

  if not IsTmuxRunnerAIProcess() then
    vim.api.nvim_echo({{"Tmux runner pane has no AI process running", "ErrorMsg"}}, true, {})
    return
  end

  vim.fn.VimuxSendText("@" .. filepath .. " git diff:\n```diff\n" .. diff .. "```\n")
  vim.fn.VimuxSendKeys("S-Enter")
  FocusTmuxRunner()
end
