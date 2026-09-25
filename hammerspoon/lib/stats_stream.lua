-- The one `c-system-sensors-macos menubar` process behind the stats menubar
-- items. The helper owns the items: it samples, draws them and repaints them
-- on its own timer, so Hammerspoon paints nothing per tick. What comes back
-- here is one JSON line per event, routed to the widget it is about:
--
--   {"event":"readings", ...}              every tick, to every subscriber
--   {"event":"click","item":"system", ...} a click, to that item's subscriber
--
-- The drawing moved out because a paint here cost 3–7ms of the main thread
-- every tick, most of it the cold wake-up, plus a Core Animation commit per
-- item. A readings line is only decoded and stored — no canvas, no image, no
-- commit — and the panels behind the clicks are still drawn here.
--
-- The helper also pauses itself while the screens are locked, asleep, or
-- behind the screensaver, and resets its baselines when they come back, so
-- nothing here watches power events.
--
-- Which items exist is decided by the command line: `menubar <ms> network
-- system`. A widget subscribing or leaving restarts the helper with the new
-- list, and the last one out stops it — hidden, the items cost nothing, not
-- even the process. The status items carry an autosave name, so a restart
-- puts them back where they were.
--
-- Usage:
--   local statsStream = require("stats_stream")
--   local subscriber = { readings = applyReadings, click = openMenu }
--   statsStream.subscribe("system", subscriber)
--   statsStream.unsubscribe("system")

-- One stream per Hammerspoon instance. lib/ is on package.path, so the file
-- is reachable as both "stats_stream" and "lib.stats_stream" — two
-- package.loaded entries, and without this guard the second require would
-- start a second helper and draw every item twice.
local INSTANCE_KEY = "statsStream"

if _G[INSTANCE_KEY] ~= nil then
  return _G[INSTANCE_KEY]
end

local lineStream = require("line_stream")

local M = {}

-- Absolute path because hs.task and hs.execute do not consult the login
-- shell's PATH, which is where ~/dotfiles/bin_native/macos is added. Public
-- so a subscriber can ask the same helper for its one-shot `details` report.
M.HELPER = os.getenv("HOME") .. "/dotfiles/bin_native/macos/c-system-sensors-macos"

-- Two seconds because none of the sensor figures moves faster than that in a
-- way a reader could use, and a throughput figure read over two seconds still
-- shows every burst worth noticing. Public so a panel can refresh on the same
-- cadence the readings arrive on.
M.INTERVAL_MILLISECONDS = 2000
M.INTERVAL_SECONDS = M.INTERVAL_MILLISECONDS / 1000

-- How often a dead helper is noticed and restarted. Loose because a helper
-- that dies at all is the unexpected case — this is a backstop, not a poll.
local SUPERVISOR_SECONDS = 10

-- The items in the order the helper is told about them. It creates them in
-- its own fixed order, so this only has to be stable.
local ITEM_ORDER = { "network", "system" }


local subscribers = {}
local task = nil
local supervisorTimer = nil
local pendingSync = nil

-- Route one line: readings to everybody, a click to the item it names. Each
-- handler runs protected — the streaming callback has to keep returning true
-- to stay alive, and one widget's error must not freeze the others.
local function dispatch(line)
  local decoded, event = pcall(hs.json.decode, line)

  if not decoded or event == nil then
    return
  end

  local handlerName = event.event

  for item, subscriber in pairs(subscribers) do
    local handler = subscriber[handlerName]

    if handler ~= nil and (handlerName ~= "click" or event.item == item) then
      local succeeded, message = pcall(handler, event)

      if not succeeded then
        print("stats_stream: " .. item .. " " .. handlerName .. " failed: " .. tostring(message))
      end
    end
  end
end

-- The helper's command line: the subcommand, the tick, and the items to show.
local function arguments()
  local list = { "menubar", tostring(M.INTERVAL_MILLISECONDS) }

  for _, item in ipairs(ITEM_ORDER) do
    if subscribers[item] ~= nil then
      list[#list + 1] = item
    end
  end

  return list
end

-- Launch the helper unless it is already running or nobody wants an item.
local function startHelper()
  if lineStream.isRunning(task) or next(subscribers) == nil then
    return
  end

  task = lineStream.start(M.HELPER, arguments(), dispatch)
end

-- Terminate the helper, which takes its status items out of the bar with it.
local function stopHelper()
  lineStream.stop(task)

  task = nil
end

-- Restart with the current item list, or stop when nobody is left.
local function sync()
  stopHelper()

  if next(subscribers) == nil then
    supervisorTimer:stop()

    return
  end

  startHelper()
  supervisorTimer:start()
end

-- The deferred sync scheduleSync sets up, clearing the pending mark first so
-- a change made during the sync schedules another.
local function runPendingSync()
  pendingSync = nil
  sync()
end

-- Sync on the next run-loop turn, once however many changes came before it.
-- Both widgets subscribe while init.lua runs, and syncing on each would
-- launch a helper for the first and kill it straight away for the second.
local function scheduleSync()
  if pendingSync ~= nil then
    return
  end

  pendingSync = hs.timer.doAfter(0, runPendingSync)
end

-- Show `item` in the bar and start receiving its events: `readings(event)` on
-- every tick and `click(event)` when it is clicked.
function M.subscribe(item, subscriber)
  subscribers[item] = subscriber
  scheduleSync()
end

-- Take `item` out of the bar and stop sending it events.
function M.unsubscribe(item)
  if subscribers[item] == nil then
    return
  end

  subscribers[item] = nil
  scheduleSync()
end

-- Kill the helper and start a fresh one, which is the only "refresh" a
-- stream has: the readings arrive on their own, and the useful manual action
-- is bringing it back after killing its process by hand.
function M.restart()
  sync()
end

-- Send the helper one command line. `lock` and `unlock` rehearse the screen
-- lock without locking anything:
--   hs -c 'require("stats_stream").send("lock")'
function M.send(command)
  if lineStream.isRunning(task) then
    task:setInput(command .. "\n")
  end
end

-- A reload tears down this Lua state without necessarily stopping the
-- previous helper, and its items would sit in the bar next to the new ones
-- until its next write failed. Killed synchronously, before anything starts
-- a new one the pattern would also match.
--
-- Anchored to the helper's own path at the start of the command line: an
-- unanchored pattern also matches any shell, grep or editor whose arguments
-- merely mention the helper — the shell running this pkill included.
local STRAY_PATTERN = "^" .. M.HELPER .. " menubar"

hs.execute("/usr/bin/pkill -f '" .. STRAY_PATTERN .. "'")

supervisorTimer = hs.timer.new(SUPERVISOR_SECONDS, startHelper)

_G[INSTANCE_KEY] = M

return M
