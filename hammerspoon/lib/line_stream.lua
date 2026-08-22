-- A long-running hs.task read a line at a time. Nothing here knows what the
-- lines mean: it starts the process, reassembles whole lines out of whatever
-- the pipe delivered, and stops it again.
--
-- Streaming a helper beats spawning one per refresh: the spawn alone cost
-- about 13ms of Hammerspoon's main thread — six times the actual reading —
-- and it was paid on every tick.
--
-- Usage:
--   local lineStream = require("line_stream")
--   local task = lineStream.start(path, { "watch", "2000" }, handleLine)
--   lineStream.stop(task)

local M = {}

-- A streaming callback that hands whole lines to `handleLine`. hs.task
-- delivers whatever the pipe had, which is usually one line and occasionally
-- half of one, so the remainder is carried to the next call.
local function lineReader(handleLine)
  local pending = ""

  return function(_, stdout, _)
    if stdout == nil then
      return true
    end

    pending = pending .. stdout

    while true do
      local newline = pending:find("\n")

      if newline == nil then
        break
      end

      handleLine(pending:sub(1, newline - 1))
      pending = pending:sub(newline + 1)
    end

    return true
  end
end

-- Start `path` with `arguments`, or nil when it could not be launched.
-- hs.task.new hands back a task object even for a path that does not exist;
-- the failure only shows up as start() returning false.
function M.start(path, arguments, handleLine)
  local task = hs.task.new(path, nil, lineReader(handleLine), arguments)

  if task == nil or not task:start() then
    return nil
  end

  return task
end

-- Terminate a task started here. Safe on nil and on one that already died,
-- which is what a helper that crashed between two supervisor ticks looks
-- like.
function M.stop(task)
  if task ~= nil and task:isRunning() then
    task:terminate()
  end
end

-- Whether a task started here is still delivering lines, so a supervisor can
-- decide to start it again without reaching into hs.task itself.
function M.isRunning(task)
  return task ~= nil and task:isRunning()
end

return M
