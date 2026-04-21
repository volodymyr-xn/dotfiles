local M = {}

local DEFAULT_WATCH_COMMANDS = {
  "yarn run build:js:esbuild:watch",
  "yarn run build:css:watch",
}

local PROCESS_TREE_DEPTH = 3

-- Reads per-project watch commands from <git-root>/.nvim-watchers (one command per line).
-- Falls back to DEFAULT_WATCH_COMMANDS when the file is absent or empty.
local function load_watch_commands()
  local git_root = vim.fn.systemlist("git rev-parse --show-toplevel 2>/dev/null")[1]
  if not git_root or git_root == "" or git_root:match("^fatal") then
    return DEFAULT_WATCH_COMMANDS
  end

  local f = io.open(git_root .. "/.nvim-asset-watcher-commands", "r")
  if not f then return DEFAULT_WATCH_COMMANDS end

  local cmds = {}
  for line in f:lines() do
    line = line:match("^%s*(.-)%s*$")
    if line ~= "" and not line:match("^#") then
      table.insert(cmds, line)
    end
  end
  f:close()

  return #cmds > 0 and cmds or DEFAULT_WATCH_COMMANDS
end

-- Scans all panes in the current tmux session; returns list of { pane_id, command }.
-- Uses a single `ps -axo` snapshot instead of recursive pgrep chains — walks UP
-- from each matching process to find its pane root.
local function find_watch_panes(watch_commands)
  local patterns = vim.tbl_map(vim.pesc, watch_commands)

  local panes_output = vim.fn.system("tmux list-panes -s -F '#{pane_id} #{pane_pid}'")
  local pane_by_pid = {}

  for line in panes_output:gmatch("[^\n]+") do
    local pane_id, pane_pid = line:match("(%S+)%s+(%S+)")
    if pane_id and pane_pid then
      pane_by_pid[pane_pid] = pane_id
    end
  end

  if vim.tbl_isempty(pane_by_pid) then return {} end

  local pid_to_ppid = {}
  local pid_to_args = {}

  local ps_output = vim.fn.system("ps -axo pid=,ppid=,args=")
  for line in ps_output:gmatch("[^\n]+") do
    local pid, ppid, args = line:match("^%s*(%d+)%s+(%d+)%s+(.+)$")
    if pid then
      pid_to_ppid[pid] = ppid
      pid_to_args[pid] = args
    end
  end

  -- Walk up the process tree from pid until a pane root is found or depth exceeded
  local function find_pane_id(pid)
    local cur = pid
    for _ = 1, PROCESS_TREE_DEPTH + 1 do
      if pane_by_pid[cur] then return pane_by_pid[cur] end
      local parent = pid_to_ppid[cur]
      if not parent or parent == cur or parent == "1" then return nil end
      cur = parent
    end
  end

  local seen = {}
  local matches = {}

  for pid, args in pairs(pid_to_args) do
    local pane_id = find_pane_id(pid)
    if pane_id and not seen[pane_id] then
      for i, pattern in ipairs(patterns) do
        if args:match(pattern) then
          table.insert(matches, { pane_id = pane_id, command = watch_commands[i] })
          seen[pane_id] = true
          break
        end
      end
    end
  end

  return matches
end

-- Finds all panes running watch commands in the current session and restarts each one
function M.restart_watchers()
  if not vim.env.TMUX or vim.env.TMUX == "" then
    vim.notify("Not inside a tmux session", vim.log.levels.WARN)
    return
  end

  local watch_commands = load_watch_commands()
  local panes = find_watch_panes(watch_commands)

  if #panes == 0 then
    vim.notify("No watch panes found in current tmux session", vim.log.levels.WARN)
    return
  end

  for _, pane in ipairs(panes) do
    local id = pane.pane_id
    -- Sleep between interrupt and restart to let the process exit cleanly
    vim.fn.system(
      "tmux send-keys -t " .. id .. " C-c ''" ..
      " ; sleep 0.15 ; " ..
      "tmux send-keys -t " .. id .. " " .. vim.fn.shellescape(pane.command) .. " Enter"
    )
  end

  local lines = { " Watchers restarted (" .. #panes .. ")" }
  for _, pane in ipairs(panes) do
    table.insert(lines, "  ↺  " .. pane.command)
  end

  local width = 0
  for _, line in ipairs(lines) do
    if #line > width then width = #line end
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local win = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    anchor = "SE",
    row = vim.o.lines - vim.o.cmdheight - 1,
    col = vim.o.columns,
    width = width + 2,
    height = #lines,
    style = "minimal",
    border = "rounded",
    noautocmd = true,
  })

  vim.api.nvim_win_set_hl_ns(win, vim.api.nvim_create_namespace("tmux_watcher_float"))
  vim.api.nvim_set_option_value("winhl", "Normal:DiagnosticInfo", { win = win })

  vim.defer_fn(function()
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
    if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
  end, 3000)
end

return M
