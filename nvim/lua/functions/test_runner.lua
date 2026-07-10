-- Picks the tmux pane vim-test runs in. Vimux's own lookup takes the first
-- non-active pane in the window whatever runs there, which drops test
-- commands into an AI agent, a server or a log tail; this module resolves a
-- genuinely idle pane instead, and splits a fresh one when every other pane
-- is busy.

local tmux_panes = require("functions.tmux_panes")

local OWNER = "test"
local NO_PANE_MSG = "Could not open a tmux pane for tests"

-- Height of a test pane stacked under an existing side column, as a share
-- of the pane it is split off
local STACKED_PANE_SIZE = "50%"

-- Disable Vimux's "first non-active pane" guess for every caller (vim-test
-- and my_plugins/renpy_tools.lua). Set here rather than in
-- plugin_settings/vim_test.lua because that file only loads once a Test*
-- command fires, which is too late for other Vimux callers.
vim.g.VimuxUseNearest = false

-- Titles panes Vimux creates (select-pane -T) and filters Vimux's own
-- lookups to that title, so even a code path that bypasses this module can
-- no longer land on an AI pane. tmux.conf's `allow-rename off` is
-- window-scoped and does not block pane titles.
vim.g.VimuxRunnerName = "vim-test"

-- Side-by-side split, the layout Vimux still uses for its other callers.
-- Set here for the same reason as the two globals above; `VimuxHeight` is
-- a width in this orientation (`split-window -l 80 -h`, i.e. 80 columns;
-- a bare number is cells, vimux's own default '20%' is a percentage).
vim.g.VimuxOrientation = "h"
vim.g.VimuxHeight = "80"

local M = {}

-- Returns the pane this module used last time, if it is still present and
-- still idle, so repeated runs reuse one pane instead of wandering
local function previous_pane(window_panes)
  local claimed_id = tmux_panes.claimed_by(OWNER)

  if not claimed_id then return nil end

  for _, pane in ipairs(window_panes) do
    if pane.id == claimed_id and tmux_panes.is_free(pane, OWNER) then return pane end
  end

  return nil
end

local function first_free_pane(window_panes)
  for _, pane in ipairs(window_panes) do
    if tmux_panes.is_free(pane, OWNER) then return pane end
  end

  return nil
end

local function nvim_pane(window_panes)
  for _, pane in ipairs(window_panes) do
    if pane.active == "1" then return pane end
  end

  return nil
end

-- Tallest pane sitting beside nvim rather than above or below it; nil when
-- nvim's column is the only one. Tallest so that a window whose side column
-- is already stacked keeps splitting the roomiest pane of it.
local function tallest_side_pane(window_panes, current_pane)
  local target = nil

  for _, pane in ipairs(window_panes) do
    if pane.left ~= current_pane.left and (not target or pane.height > target.height) then
      target = pane
    end
  end

  return target
end

-- Splits `target_id` and returns the new pane's id, or nil when tmux
-- refuses. `-d` keeps the cursor in nvim, `-c` gives the pane nvim's cwd
-- (it would otherwise inherit the cwd of whichever pane was split), and the
-- title matches VimuxRunnerName so Vimux's own lookups resolve to it too.
local function create_pane(target_id, orientation, size)
  local command = table.concat({
    "tmux split-window -d",
    "-t " .. target_id,
    "-" .. orientation,
    "-l " .. size,
    "-c " .. vim.fn.shellescape(vim.fn.getcwd()),
    "-P -F '#{pane_id}'",
  }, " ")

  local pane_id = vim.trim(vim.fn.system(command))

  if vim.v.shell_error ~= 0 or pane_id == "" then return nil end

  vim.fn.system(
    "tmux select-pane -t " .. pane_id .. " -T " .. vim.fn.shellescape(vim.g.VimuxRunnerName)
  )

  return pane_id
end

-- New column next to nvim, matching the layout Vimux produces on its own
local function open_pane_beside(current_pane)
  return create_pane(current_pane.id, vim.g.VimuxOrientation, vim.g.VimuxHeight)
end

-- New pane stacked under an existing side column, so nvim keeps its size
local function open_pane_under(side_pane)
  return create_pane(side_pane.id, "v", STACKED_PANE_SIZE)
end

-- Adds a pane for the tests: stacked under the neighbouring column when
-- there is one, otherwise split off nvim itself
local function open_runner_pane(window_panes)
  local current_pane = nvim_pane(window_panes)

  if not current_pane then return nil end

  local side_pane = tallest_side_pane(window_panes, current_pane)

  if side_pane then return open_pane_under(side_pane) end

  return open_pane_beside(current_pane)
end

-- Points Vimux at the pane the test should run in. Returns false only when
-- no pane could be opened at all (nvim outside tmux), so the caller runs
-- nothing.
local function select_runner_pane()
  local window_panes = tmux_panes.list_panes()
  local target = previous_pane(window_panes) or first_free_pane(window_panes)
  local pane_id = target and target.id or open_runner_pane(window_panes)

  if not pane_id then
    vim.notify(NO_PANE_MSG, vim.log.levels.ERROR)

    return false
  end

  vim.g.VimuxRunnerIndex = pane_id
  tmux_panes.claim(OWNER, pane_id)

  return true
end

-- Runs a vim-test command (TestNearest, TestFile, TestLast, ...) in a pane
-- that is not busy with another process
function M.run(command)
  if not select_runner_pane() then return end

  vim.cmd(command)

  tmux_panes.claim(OWNER, vim.g.VimuxRunnerIndex)
end

return M
