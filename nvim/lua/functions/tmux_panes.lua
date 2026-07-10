-- Shared tmux pane inventory for every feature that targets a pane from
-- nvim (functions/tmux.lua sends code to AI panes, functions/test_runner.lua
-- runs tests). Owns pane listing, AI-process detection, the "is this pane
-- idle" rule, and a registry of which feature claimed which pane so the two
-- never fight over the same target.

local AI_PROCESS_NAMES = { "claude", "agent" }
local PROCESS_TREE_DEPTH = 3
-- If process not found increase depth to 4 or 5
-- local PROCESS_TREE_DEPTH = 4

-- Claude's pane-title status prefix: "✳" when idle, a braille spinner
-- frame (U+2800-U+28FF, bytes E2 A0-A3 80-BF) while working
local TITLE_STATUS_PATTERNS = {
  { pattern = "^✳%s*(.+)", status = "idle" },
  { pattern = "^\226[\160-\163][\128-\191]%s*(.+)", status = "busy" },
}

-- Foreground commands that mean the pane sits at a prompt. Anything else
-- (nvim, ruby, node, tail, less, ssh, ...) is running something we must not
-- interrupt. Note this is necessary but not sufficient: a Claude Code pane
-- also reports "bash", which is why is_free() additionally walks the
-- process tree and inspects the pane title.
local SHELL_COMMANDS = {
  zsh = true,
  bash = true,
  sh = true,
  fish = true,
  dash = true,
}

-- pane_title stays last: it is the only field that may contain spaces
local PANE_FORMAT = table.concat({
  "#{pane_id}",
  "#{pane_pid}",
  "#{pane_index}",
  "#{pane_active}",
  "#{pane_left}",
  "#{pane_height}",
  "#{pane_current_command}",
  "#{pane_title}",
}, " ")

-- pane_id currently claimed by each feature, keyed by owner name
local claims = {}

local M = {}

-- Lists the panes of the current tmux window as
-- { id, pid, index, active, left, height, command, title }. `left` and
-- `height` are cell coordinates, used to tell columns apart when a new
-- pane has to be split off.
function M.list_panes()
  local output = vim.fn.system("tmux list-panes -F '" .. PANE_FORMAT .. "'")
  local panes = {}

  for line in output:gmatch("[^\n]+") do
    local id, pid, index, active, left, height, command, title =
      line:match("(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s*(.*)")

    if id then
      table.insert(panes, {
        id = id,
        pid = pid,
        index = index,
        active = active,
        left = tonumber(left),
        height = tonumber(height),
        command = command,
        title = title,
      })
    end
  end

  return panes
end

-- Walks a process tree from root_pid; returns matched AI process name or nil
function M.ai_process_name(root_pid)
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

-- Extracts the AI session name and busy/idle status from a pane title.
-- Claude sets the title via OSC escapes; panes without one keep tmux's
-- default (the host name), which carries no session info, so it is
-- treated as absent.
function M.session_from_title(title)
  title = vim.trim(title or "")

  if title == "" or title == vim.fn.hostname() then return nil, nil end

  for _, rule in ipairs(TITLE_STATUS_PATTERNS) do
    local name = title:match(rule.pattern)

    if name then return name, rule.status end
  end

  return title, nil
end

-- Cancels tmux copy/selection mode on the pane so keys reach the running
-- process; sending text while in copy mode is interpreted as copy-mode
-- navigation and never reaches the target.
function M.exit_copy_mode(pane_id)
  local in_mode = vim.fn.system("tmux display-message -p -t " .. pane_id .. " '#{pane_in_mode}'")

  if in_mode:match("1") then
    vim.fn.system("tmux send-keys -t " .. pane_id .. " -X cancel")
  end
end

-- Records the pane a feature is using, so other features skip it
function M.claim(owner, pane_id)
  claims[owner] = pane_id
end

function M.claimed_by(owner)
  return claims[owner]
end

function M.release(owner)
  claims[owner] = nil
end

local function claimed_by_others(pane_id, owner)
  for claim_owner, claimed_id in pairs(claims) do
    if claim_owner ~= owner and claimed_id == pane_id then return true end
  end

  return false
end

-- True when the pane is safe for `owner` to run a command in: not the pane
-- nvim itself lives in, sitting at a shell prompt, no AI process anywhere
-- in its tree, no AI status glyph left in its title, and not claimed by a
-- different feature.
function M.is_free(pane, owner)
  if pane.active == "1" then return false end

  if not SHELL_COMMANDS[pane.command] then return false end

  if claimed_by_others(pane.id, owner) then return false end

  if M.ai_process_name(pane.pid) then return false end

  local _, status = M.session_from_title(pane.title)

  return status == nil
end

return M
