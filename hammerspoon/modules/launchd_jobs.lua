-- Menubar list of the custom launchd agents in ~/Library/LaunchAgents. A
-- summary header — how many are loaded or failing, and which runs next —
-- sits over one card per job: its name and description, a countdown to its
-- next run, its schedule, how far it is from its last run to its next, and
-- how that last run ended. Hovering a card opens a submenu to run the job
-- now, open its log, reveal its plist, or remove it through
-- c-launchd-agent-remove.
--
-- "Custom" is everything in that directory except the agents other software
-- installed (VENDOR_PREFIXES), so a new agent shows up without an edit here.
-- The name and description are `Name` and `Description` keys in the job's
-- own plist: launchd ignores keys it does not know, and the text stays next
-- to the job.
--
-- A native menu of drawn cards rather than a canvas_panel: nothing here
-- changes second to second, and the actions want submenus, which only an
-- NSMenu has. The cards are drawn by lib/launchd_job_card and the schedule
-- read by lib/launchd_schedule; this file reads the system and wires the
-- menu. Everything is re-read when the menu opens, so it never shows a
-- reading older than the click.
--
-- Last run is the modification time of the job's log. launchd keeps no
-- timestamp of its own and restarts its run counter at every load, so the
-- log is the one record that survives a reboot — exact for any job that
-- writes output on every run, which all of control_panel's do.

-- One widget per Hammerspoon instance, for the same reason process_stats.lua
-- guards itself: modules/ is on package.path, so this file is reachable under
-- two names and a second require would add a second clock.
local INSTANCE_KEY = "launchdJobsWidget"

if _G[INSTANCE_KEY] ~= nil then
  return _G[INSTANCE_KEY]
end

local canvasBanner = require("canvas_banner")
local launchdJobCard = require("launchd_job_card")
local launchdSchedule = require("launchd_schedule")
local statFormat = require("stat_format")
local statPanel = require("stat_panel")

local HOME = os.getenv("HOME")
local AGENTS_DIRECTORY = HOME .. "/Library/LaunchAgents"

-- Absolute paths, because hs.task and hs.execute do not consult the login
-- shell's PATH, which is where ~/control_panel/bin is added.
local LAUNCHCTL = "/bin/launchctl"
local OPEN = "/usr/bin/open"
local REMOVE_SCRIPT = HOME .. "/control_panel/bin/c-launchd-agent-remove"

-- The per-user launchd domain the agents are loaded into.
local DOMAIN = "gui/" .. (hs.execute("/usr/bin/id -u"):gsub("%s+$", ""))

-- Agents installed by other software rather than written by hand. Matched
-- against the file name, so their plists — often binary — are never read.
local VENDOR_PREFIXES = {
  "com.google.",
  "com.microsoft.",
  "com.tenorshare.",
  "homebrew.mxcl.",
  "org.virtualbox.",
}

-- Template icon in gear.svg's box, so it sits at the gear's size.
local ICON_PATH = hs.configdir .. "/assets/clock.svg"
local ICON_FALLBACK_TITLE = "jobs"

-- nf-md-play / nf-md-delete / nf-md-alert_circle — banner glyphs.
local RUN_ICON = "󰐊"
local REMOVE_ICON = "󰆴"
local FAILURE_ICON = "󰀨"

local HEADER_TITLE = "Launchd agents"
local DATE_FORMAT = "%a %d %b %H:%M"

-- Separates the phrases of one line in the plain-text mirror.
local SEPARATOR = "  ·  "

-- A countdown shorter than this is drawn in accent: the job is about to run.
local SOON_SECONDS = 60 * 60
local SECONDS_PER_MINUTE = 60

-- launchctl's last exit code for a job that has not finished a run since it
-- was loaded.
local NEVER_EXITED = "(never exited)"

local menu = hs.menubar.new()

-- Tasks in flight, held so the garbage collector cannot reap one before its
-- callback fires.
local runningTasks = {}

-- True for an agent some installer put there rather than a hand-written one.
local function isVendorAgent(fileName)
  for _, prefix in ipairs(VENDOR_PREFIXES) do
    if fileName:sub(1, #prefix) == prefix then
      return true
    end
  end

  return false
end

-- Sort order for the menu.
local function byLabel(left, right)
  return left.label < right.label
end

-- Every custom agent's plist, read and sorted by label.
local function customJobs()
  local jobs = {}

  for fileName in hs.fs.dir(AGENTS_DIRECTORY) do
    if fileName:match("%.plist$") and not isVendorAgent(fileName) then
      local path = AGENTS_DIRECTORY .. "/" .. fileName
      local definition = hs.plist.read(path)

      if definition ~= nil then
        jobs[#jobs + 1] = {
          label = definition.Label or fileName:match("^(.*)%.plist$"),
          path = path,
          definition = definition,
        }
      end
    end
  end

  table.sort(jobs, byLabel)

  return jobs
end

-- The log both of the job's streams go to, as launchd writes them.
local function logPath(definition)
  return definition.StandardOutPath or definition.StandardErrorPath
end

-- The job's log when it has been written at least once, nil otherwise.
local function existingLog(definition)
  local path = logPath(definition)

  if path == nil or hs.fs.attributes(path) == nil then
    return nil
  end

  return path
end

-- When the job last wrote to its log, standing in for when it last ran.
local function lastRun(definition)
  local path = existingLog(definition)

  if path == nil then
    return nil
  end

  return hs.fs.attributes(path, "modification")
end

-- launchd's view of a loaded job, from `launchctl print`; nil when it is not
-- loaded. Fields are matched at the top level only — one tab in — because
-- nested blocks repeat `state =` for their own event channels.
local function serviceState(label)
  local output, succeeded = hs.execute(string.format("%s print %q 2>/dev/null",
    LAUNCHCTL, DOMAIN .. "/" .. label))

  if not succeeded then
    return nil
  end

  return {
    running = output:match("\n\tstate = ([^\n]+)") == "running",
    pid = output:match("\n\tpid = (%d+)"),
    lastExit = output:match("\n\tlast exit code = ([^\n]+)"),
  }
end

-- The job's name for its card: the plist's `Name`, or the last segment of
-- its label with dashes read as spaces ("backup-art-disk" → "Backup art
-- disk").
local function displayName(definition, label)
  if definition.Name ~= nil then
    return definition.Name
  end

  local words = (label:match("([^.]+)$") or label):gsub("-", " ")

  return words:sub(1, 1):upper() .. words:sub(2)
end

-- How the last run since load ended: "ok", "failed", or "none" when launchd
-- has not seen one finish.
local function exitOutcome(state)
  if state == nil or state.lastExit == nil or state.lastExit == NEVER_EXITED then
    return "none"
  end

  if tonumber(state.lastExit:match("^%-?%d+")) == 0 then
    return "ok"
  end

  return "failed"
end

-- The one word the status dot stands for.
local function jobStatus(state, exit)
  if state == nil then
    return "unloaded"
  end

  if state.running then
    return "running"
  end

  if exit == "failed" then
    return "failing"
  end

  return "loaded"
end

-- Loaded, running or neither, in words.
local function stateText(state)
  if state == nil then
    return "Not loaded"
  end

  if state.running then
    return "Running · pid " .. (state.pid or "?")
  end

  return "Loaded"
end

-- "in 3d 4h". Under a minute has no figure worth drawing.
local function untilText(seconds)
  if seconds < SECONDS_PER_MINUTE then
    return "in <1m"
  end

  return "in " .. statFormat.uptime(seconds)
end

-- "Ran 3d 20h ago", or "No run logged" without a log to date it.
local function lastRunText(lastRunAt, now)
  if lastRunAt == nil then
    return "No run logged"
  end

  local elapsed = now - lastRunAt

  if elapsed < SECONDS_PER_MINUTE then
    return "Ran just now"
  end

  return "Ran " .. statFormat.uptime(elapsed) .. " ago"
end

-- The schedule phrases a card draws as chips: every trigger, except a weekly
-- calendar, which the weekday strip already draws.
local function scheduleChips(schedule)
  local chips = {}

  if schedule.weekly == nil and schedule.calendar ~= nil then
    chips[1] = schedule.calendar
  end

  for _, trigger in ipairs(schedule.others) do
    chips[#chips + 1] = trigger
  end

  if #chips == 0 and schedule.weekly == nil then
    chips[1] = "On demand"
  end

  return chips
end

-- How far the job is from its last run to its next; nil without both ends.
local function runProgress(lastRunAt, nextRunAt, now)
  if lastRunAt == nil or nextRunAt == nil then
    return nil
  end

  return statPanel.fraction(now - lastRunAt, nextRunAt - lastRunAt)
end

-- One job read in full: the card's view, plus what the header, the actions
-- and the text mirror need.
local function jobView(job, now)
  local definition = job.definition
  local state = serviceState(job.label)
  local exit = exitOutcome(state)
  local lastRunAt = lastRun(definition)
  local nextRunAt = launchdSchedule.nextRun(definition, lastRunAt, now)
  local schedule = launchdSchedule.schedule(definition)

  return {
    job = job,
    loaded = state ~= nil,
    log = existingLog(definition),
    nextRunAt = nextRunAt,
    cadence = launchdSchedule.cadence(definition, SEPARATOR),
    name = displayName(definition, job.label),
    label = job.label,
    description = definition.Description,
    status = jobStatus(state, exit),
    countdown = nextRunAt ~= nil and untilText(nextRunAt - now) or nil,
    soon = nextRunAt ~= nil and nextRunAt - now < SOON_SECONDS,
    nextDate = nextRunAt ~= nil and os.date(DATE_FORMAT, nextRunAt) or nil,
    weekly = schedule.weekly,
    todaySlot = launchdSchedule.weekdaySlot(os.date("*t", now).wday - 1),
    chips = scheduleChips(schedule),
    progress = runProgress(lastRunAt, nextRunAt, now),
    exit = exit,
    lastRun = lastRunText(lastRunAt, now),
    exitText = exit == "failed" and ("exit " .. state.lastExit) or nil,
    state = stateText(state),
  }
end

-- Every custom job, read once as of now.
local function jobViews()
  local now = os.time()
  local views = {}

  for _, job in ipairs(customJobs()) do
    views[#views + 1] = jobView(job, now)
  end

  return views
end

-- The summary over the cards, from the same reading the cards were made of.
local function headerView(views)
  local loaded = 0
  local failing = 0
  local nextView = nil

  for _, view in ipairs(views) do
    if view.loaded then
      loaded = loaded + 1
    end

    if view.status == "failing" then
      failing = failing + 1
    end

    if view.nextRunAt ~= nil
      and (nextView == nil or view.nextRunAt < nextView.nextRunAt) then
      nextView = view
    end
  end

  local loadedText = loaded == #views and string.format("%d loaded", loaded)
    or string.format("%d of %d loaded", loaded, #views)

  return {
    title = HEADER_TITLE,
    loaded = #views > 0 and loadedText or nil,
    failing = failing > 0 and string.format("%d failing", failing) or nil,
    nextName = nextView ~= nil and nextView.name or nil,
    nextIn = nextView ~= nil and nextView.countdown or nil,
    empty = #views == 0 and "No custom agents in ~/Library/LaunchAgents"
      or "Nothing scheduled to run",
  }
end

-- First line of a command's error output, for a banner subtitle.
local function firstLine(text)
  return text ~= nil and text:match("[^\n]+") or nil
end

-- Run a command off the main thread and hand its result to `onExit`.
local function runTask(path, arguments, onExit)
  local task

  -- Release the task before reporting, so a failing callback cannot leak it.
  local function finish(exitCode, standardOutput, standardError)
    runningTasks[task] = nil
    onExit(exitCode, standardOutput, standardError)
  end

  task = hs.task.new(path, finish, arguments)
  runningTasks[task] = true
  task:start()
end

-- Nothing to report: `open` either shows the file or shows its own error.
local function ignoreResult() end

-- Clicking the header does nothing, but a menu item still needs an action:
-- AppKit disables any item without one and draws its image dimmed.
local function ignoreClick() end

-- A task callback that banners how an action on `label` went:
-- `titles.done` on success, `titles.failed` with the command's own error
-- otherwise.
local function bannerResult(titles, label, icon)
  -- hs.task's exit callback.
  local function report(exitCode, _, standardError)
    if exitCode == 0 then
      canvasBanner.show({ title = titles.done, subtitle = label, icon = icon })

      return
    end

    canvasBanner.show({
      title = titles.failed,
      subtitle = firstLine(standardError) or label,
      state = "off",
      icon = FAILURE_ICON,
    })
  end

  return report
end

-- Start a loaded job now, outside its schedule. No -k: a run already in
-- progress is left alone rather than killed and restarted.
local function runNow(label)
  runTask(LAUNCHCTL, { "kickstart", DOMAIN .. "/" .. label }, bannerResult(
    { done = "Job started", failed = "Could not start job" }, label, RUN_ICON))
end

-- Open the log in whatever app .log files open in (Console by default).
local function openLog(path)
  runTask(OPEN, { path }, ignoreResult)
end

-- Reveal the file the LaunchAgents link points at, which is the one to edit.
local function revealPlist(path)
  runTask(OPEN, { "-R", hs.fs.pathToAbsolute(path) or path }, ignoreResult)
end

-- Ask first: the script deletes the plist itself, and one never committed
-- to control_panel is gone for good.
local function confirmRemoval(label)
  hs.focus()

  local choice = hs.dialog.blockAlert("Remove " .. label .. "?",
    "Unloads the agent and deletes its plist from ~/Library/LaunchAgents and "
      .. "control_panel/configs/launchd. Its log is kept.",
    "Remove", "Cancel", "critical")

  if choice ~= "Remove" then
    return
  end

  runTask(REMOVE_SCRIPT, { label }, bannerResult(
    { done = "Agent removed", failed = "Could not remove agent" },
    label, REMOVE_ICON))
end

-- The submenu behind a job's card.
local function actionItems(view)
  local label = view.job.label
  local path = view.job.path
  local log = view.log

  return {
    {
      title = "Run now",
      disabled = not view.loaded,
      fn = function() runNow(label) end,
    },
    {
      title = "Open log",
      disabled = log == nil,
      fn = function() openLog(log) end,
    },
    { title = "Reveal plist", fn = function() revealPlist(path) end },
    { title = "-" },
    {
      title = "Remove…",
      disabled = hs.fs.attributes(REMOVE_SCRIPT) == nil,
      fn = function() confirmRemoval(label) end,
    },
  }
end

-- The header and one card per job, drawn from a single reading, in the
-- appearance of the moment. template(false) keeps their colours: the default
-- treats an image as a mask and repaints it in the menu's own tint.
local function drawnImages()
  local resting = statPanel.textColor()
  local views = jobViews()
  local cards = {}

  for index, view in ipairs(views) do
    cards[index] = launchdJobCard.jobImage(view, resting):template(false)
  end

  local header = launchdJobCard.headerImage(headerView(views), resting)

  return header:template(false), cards, views
end

-- The whole menu, re-read and redrawn on every open.
local function menuItems()
  local header, cards, views = drawnImages()
  local items = {
    { title = "", image = header, fn = ignoreClick },
  }

  for index, view in ipairs(views) do
    items[#items + 1] = { title = "-" }
    items[#items + 1] = {
      title = "",
      image = cards[index],
      menu = actionItems(view),
    }
  end

  return items
end

-- One job's card as lines of text.
local function viewLines(view)
  local nextRunLine = view.nextDate ~= nil
    and string.format("Next run %s (%s)", view.nextDate, view.countdown)
    or "No next run scheduled"
  local lastRunLine = view.lastRun

  if view.exitText ~= nil then
    lastRunLine = lastRunLine .. SEPARATOR .. view.exitText
  end

  return {
    string.format("%s (%s)", view.name, view.label),
    "  " .. (view.description or "No description"),
    "  " .. view.cadence,
    "  " .. nextRunLine,
    "  " .. lastRunLine,
    "  " .. view.state,
  }
end

-- The menu as plain text, for reading it from `hs -c` without opening it.
local function text()
  local lines = {}

  for _, view in ipairs(jobViews()) do
    for _, line in ipairs(viewLines(view)) do
      lines[#lines + 1] = line
    end
  end

  return table.concat(lines, "\n")
end

-- Pop the menu open under the clock, as a click would.
local function show()
  local frame = menu:frame()

  menu:popupMenu({ x = frame.x, y = frame.y + frame.h })
end

local icon = hs.image.imageFromPath(ICON_PATH)

if icon ~= nil then
  menu:setIcon(icon, true)
else
  -- A missing asset costs the clock, not the widget.
  menu:setTitle(ICON_FALLBACK_TITLE)
end

menu:setMenu(menuItems)

local widget = {
  show = show,
  text = text,
  -- The drawn header and cards, for rendering them to files from `hs -c`.
  images = drawnImages,
}

_G[INSTANCE_KEY] = widget

return widget
