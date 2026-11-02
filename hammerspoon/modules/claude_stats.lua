-- Menubar item for every Claude Code profile on this machine: an AI sparkle
-- in the bar, and everything else in the panel it opens. The sparkle turns
-- into Claude Code's spinner, in blue, while a session works and goes orange
-- while one waits for you; beyond that, nothing is read while the panel is
-- closed. The panel reads its figures when it opens and keeps them current
-- while it stays open.
--
-- Clicking the item opens a panel styled after ClaudeBar
-- (github.com/LHner1/claude-bar): limit rings per profile and the sessions
-- grouped by profile. It is an hs.webview rather than a canvas, because the
-- look it copies — rings, grouped lists — is SwiftUI's, and HTML gets
-- closer to that than canvas elements do. Clicking a session brings its
-- terminal to the front, switching tmux to its pane when it runs in one;
-- Cmd+K then returns, as after an agent notification (notify_return).
--
-- Everything shown comes from c-claude-stats-macos, a Swift helper kept
-- running for as long as Hammerspoon runs (see
-- native_modules/macos/c-claude-stats-macos.swift). It reads the session
-- files and the statusline's limit caches off this thread, only while told
-- `live`, and prints a line only when something changed. A `sessions` line
-- is decoded here for the limits: their colours come from the statusline's own code (its Go port's `burn-colors`
-- subcommand in control_panel), so the panel and the statusline always agree.
--
-- Build the helper once with `dotfiles_setup/build_native_modules.sh`; until
-- then the panel stays empty.
--
-- Inspect from the shell:
--   hs -c 'require("claude_stats").show()'
--   hs -c 'return hs.inspect(require("claude_stats").frame())'
--   hs -c 'return require("claude_stats").barState()'

-- One widget per Hammerspoon instance. modules/ is on package.path, so the
-- file is reachable as both "claude_stats" and "modules.claude_stats" — two
-- package.loaded entries, and without this guard the second require would
-- start a second helper and a second item.
local INSTANCE_KEY = "claudeStatsWidget"

if _G[INSTANCE_KEY] ~= nil then
  return _G[INSTANCE_KEY]
end

local lineStream = require("line_stream")
local notifyReturn = require("notify_return")

local M = {}

local HOME = os.getenv("HOME")

-- Absolute paths because hs.task does not consult the login shell's PATH.
local HELPER = HOME .. "/dotfiles/bin_native/macos/c-claude-stats-macos"
local CLAUDE_EXECUTABLE = HOME .. "/.local/bin/claude"
local FOCUS_SCRIPT = HOME .. "/dotfiles/scripts/macos/c-claude-session-focus-macos.sh"
-- The tmux AI pane picker's source; the panel lists only the sessions it does.
local TMUX_PANE_LIST = HOME .. "/control_panel/bin/c-tmux-ai-pane-list"
local PANEL_PAGE = hs.configdir .. "/assets/claude_stats/panel.html"

-- The statusline's own limit colouring (control_panel statuslines): its Go
-- port answers `burn-colors` with one colour name per window, so the panel
-- colours a limit exactly as the statusline does — same strategy, same plan
-- scaling, same projection. Not built yet, the page falls back to its own
-- thresholds.
local COLOR_COMMAND = HOME .. "/control_panel/configs/claude/statuslines/command-go"

-- The panel's limit windows by the helper's key, the statusline's window
-- name, and the suffix of the strategy's hysteresis key.
local LIMIT_WINDOWS = {
  { key = "fiveHour", name = "five_hour", state = "5h" },
  { key = "sevenDay", name = "seven_day", state = "week" },
}

-- How often the colours are recomputed while the panel is open: projection
-- moves with the clock even while usage does not.
local LIMIT_COLOR_SECONDS = 30

-- The profiles, in the order the panel lists them. `name` is the
-- CLAUDE_PROFILE each statusline exports (it names the limit cache), `label`
-- the panel's short form (footer), `title` its long form, and
-- `directory` the CLAUDE_CONFIG_DIR the control_panel wrappers (claude, cw,
-- cdev) set.
local PROFILES = {
  { name = "claude", label = "main", title = "claude", directory = HOME .. "/.claude" },
  { name = "claude_dt", label = "dt", title = "claude-dt", directory = HOME .. "/.claude-dt" },
  { name = "claude_dev_profile", label = "dev", title = "claude-dev", directory = HOME .. "/.claude_dev_profile" },
}

-- How often a dead helper is noticed and restarted. Loose because a helper
-- that dies at all is the unexpected case — this is a backstop, not a poll.
local SUPERVISOR_SECONDS = 10

-- The bar follows the helper's `bar` line: the sparkle while every session
-- is idle or nobody can see the screen, Claude Code's spinner in blue while
-- one works, the sparkle in Claude's orange while one waits for you, and
-- the spinner in that orange while one works and another waits. The
-- figures live in the panel only. Every look keeps its own colour, white for
-- idle included, rather than being tinted for the bar as a template would.
-- The text stands in if an SVG cannot be loaded.
local ICON_SIZE = 16
local ICON = hs.image.imageFromPath(hs.configdir .. "/assets/claude_stats/ai.svg")
local WAITING_ICON = hs.image.imageFromPath(hs.configdir .. "/assets/claude_stats/ai_waiting.svg")

if ICON ~= nil then
  ICON = ICON:setSize({ w = ICON_SIZE, h = ICON_SIZE })
end

if WAITING_ICON ~= nil then
  WAITING_ICON = WAITING_ICON:setSize({ w = ICON_SIZE, h = ICON_SIZE })
end

-- What the bar shows per still state; `title` stands in for a missing image.
local LOOKS = {
  idle = { image = ICON, title = "AI" },
  waiting = { image = WAITING_ICON, title = "AI?" },
}

-- Nobody can see the bar while away, so it keeps still on the sparkle.
LOOKS.away = LOOKS.idle

-- The CLI's own spinner glyphs and pace, played forwards then back.
local SPINNER_GLYPHS = { "·", "✢", "✳", "✶", "✻", "✽" }
local SPINNER_SECONDS = 0.12
-- Catppuccin Macchiato blue, the workmux theme's colour for a working agent.
local SPINNER_COLOR = { hex = "#8aadf4" }
-- Claude's orange, as in the waiting sparkle.
local WAITING_SPINNER_COLOR = { hex = "#d97757" }
-- Sized and nudged up so the glyphs sit where the sparkle does.
local SPINNER_TEXT_SIZE = 18
local SPINNER_TOP_OFFSET = -3

-- One spinner glyph in `color` as an image the size of the sparkle, drawn
-- at twice that and scaled down so it stays sharp on a Retina bar. Every
-- frame gets the same size, so the item keeps its width while glyphs turn.
local function glyphImage(glyph, color)
  local scale = 2
  local side = ICON_SIZE * scale
  local topOffset = SPINNER_TOP_OFFSET * scale
  local canvas = hs.canvas.new({ x = 0, y = 0, w = side, h = side })

  canvas[1] = {
    type = "text",
    text = glyph,
    textSize = SPINNER_TEXT_SIZE * scale,
    textColor = color,
    textAlignment = "center",
    frame = { x = 0, y = topOffset, w = side, h = side - topOffset },
  }

  local image = canvas:imageFromCanvas()

  canvas:delete()

  return image:setSize({ w = ICON_SIZE, h = ICON_SIZE })
end

-- The spinner's looks in `color`, in playing order: every glyph forwards,
-- then back without repeating either end.
local function spinnerLooks(color)
  local looks = {}

  for _, glyph in ipairs(SPINNER_GLYPHS) do
    looks[#looks + 1] = { image = glyphImage(glyph, color), title = glyph }
  end

  for index = #SPINNER_GLYPHS - 1, 2, -1 do
    looks[#looks + 1] = looks[index]
  end

  return looks
end

-- The spinner per moving bar state, both the same length so a switch keeps
-- the current frame.
local SPINNERS = {
  busy = spinnerLooks(SPINNER_COLOR),
  busyWaiting = spinnerLooks(WAITING_SPINNER_COLOR),
}

-- The page is 300pt wide inside a clear margin that holds its shadow; the
-- margins here match the page's body padding.
local PANEL_WIDTH = 320
local PANEL_SIDE_MARGIN = 10
local MENUBAR_GAP = 2
local SCREEN_MARGIN = 8

local ESCAPE_KEY_CODE = hs.keycodes.map.escape

local task = nil
local supervisorTimer = nil
local limitColorTimer = nil
local limitColorTask = nil
local menu = nil
local webview = nil
local outsideTap = nil
local escapeTap = nil
local pageReady = false
local panelVisible = false
local panelHeight = 600
local latestSessions = nil
local latestSessionsLine = nil
local barState = "idle"
local spinnerTimer = nil
local spinnerIndex = 1
local activeSpinner = SPINNERS.busy

-- The helper's command line: the subcommand, the CLI it asks why a session
-- waits, the picker list it narrows sessions to, then one `name=dir` per
-- profile.
local function helperArguments()
  local arguments = { "watch", CLAUDE_EXECUTABLE, TMUX_PANE_LIST }

  for _, profile in ipairs(PROFILES) do
    arguments[#arguments + 1] = profile.name .. "=" .. profile.directory
  end

  return arguments
end

-- Hand one helper line to the page, which decodes it itself.
local function pushToPanel(line)
  if webview == nil or not pageReady or not panelVisible then
    return
  end

  webview:evaluateJavaScript("window.claudeStats.update(" .. line .. ")")
end

-- Queue one `burn-colors` spec, "window_name:state_key:used:resets_at:
-- plan_profile", per window of `report` still in force; `slots` records which
-- profile and window each answer line belongs to. The strategy keeps
-- hysteresis state per key in $TMPDIR; the panel_ keys keep it apart from
-- the statusline's own, which the panel must not overwrite.
local function appendLimitSpecs(report, specs, slots)
  local limits = report.limits

  if limits == nil then
    return
  end

  for _, window in ipairs(LIMIT_WINDOWS) do
    local limit = limits[window.key]

    if limit ~= nil and limit.resetsAt > os.time() then
      local stateKey = "panel_" .. report.name .. "_" .. window.state

      specs[#specs + 1] = table.concat({ window.name, stateKey, math.floor(limit.pct), limit.resetsAt, report.name }, ":")
      slots[#slots + 1] = { profile = report.name, key = window.key }
    end
  end
end

-- Hand the page every profile's colours, { claude = { fiveHour = "yellow",
-- ... }, ... }, computed now by one off-thread `burn-colors` run.
local function pushLimitColors()
  if latestSessions == nil or not pageReady or not panelVisible or hs.fs.attributes(COLOR_COMMAND) == nil then
    return
  end

  local colors = {}
  local arguments = { "burn-colors" }
  local slots = {}

  for _, report in ipairs(latestSessions.profiles) do
    colors[report.name] = {}
    appendLimitSpecs(report, arguments, slots)
  end

  -- Kept in a module local so the task is not collected before it reports.
  limitColorTask = hs.task.new(COLOR_COMMAND, function(exitCode, stdOut)
    if exitCode ~= 0 or not pageReady or not panelVisible then
      return
    end

    local index = 0

    for name in stdOut:gmatch("[^\n]+") do
      index = index + 1
      local slot = slots[index]

      if slot ~= nil then
        colors[slot.profile][slot.key] = name
      end
    end

    webview:evaluateJavaScript("window.claudeStats.setLimitColors(" .. hs.json.encode(colors) .. ")")
  end, arguments
  )

  limitColorTask:start()
end

-- Put `look` in the bar: its image, or its title when the image is missing.
local function showLook(look)
  if look.image == nil then
    menu:setIcon(nil)
    menu:setTitle(look.title)

    return
  end

  menu:setTitle(nil)
  menu:setIcon(look.image, false)
end

-- Show the spinner's next frame.
local function turnSpinner()
  spinnerIndex = spinnerIndex % #activeSpinner + 1
  showLook(activeSpinner[spinnerIndex])
end

-- Show the helper's bar state: a spinner while busy or busyWaiting, the look
-- for idle, waiting or away otherwise. Anything unrecognised counts as idle.
local function showBarState(state)
  if SPINNERS[state] == nil and LOOKS[state] == nil then
    state = "idle"
  end

  if state == barState then
    return
  end

  barState = state
  local spinner = SPINNERS[state]

  if spinner ~= nil then
    activeSpinner = spinner
    showLook(spinner[spinnerIndex])
    spinnerTimer:start()

    return
  end

  spinnerTimer:stop()
  showLook(LOOKS[state])
end

-- A bar line sets the icon. A sessions line is kept for the next open and
-- handed to the page now if it is open; the page decodes it itself, and it
-- is also decoded here, for the limits the colours are computed from.
local function handleLine(line)
  if line:sub(2, 14) == '"event":"bar"' then
    showBarState(line:match('"state":"(%a+)"'))

    return
  end

  if line:sub(2, 19) ~= '"event":"sessions"' then
    return
  end

  local decoded, event = pcall(hs.json.decode, line)

  if decoded and event ~= nil then
    latestSessions = event
  end

  latestSessionsLine = line
  pushLimitColors()
  pushToPanel(line)
end

-- Tell the helper to start or stop reading: `live` or `idle`.
local function sendCommand(command)
  if lineStream.isRunning(task) then
    task:setInput(command .. "\n")
  end
end

-- Launch the helper unless it is already running. It starts idle, so a
-- restart behind an open panel is told to go live again. The icon drops to
-- idle until the new helper reports, so a dead one leaves no spinner behind.
local function startHelper()
  if lineStream.isRunning(task) then
    return
  end

  showBarState("idle")
  task = lineStream.start(HELPER, helperArguments(), handleLine)

  if panelVisible then
    sendCommand("live")
  end
end

-- Whether `point` falls inside `frame`, edges included.
local function containsPoint(frame, point)
  return point.x >= frame.x and point.x <= frame.x + frame.w
    and point.y >= frame.y and point.y <= frame.y + frame.h
end

-- Where the panel hangs: centred under the item the way ClaudeBar's popover
-- is, pulled back inside the screen near either edge, and no taller than
-- the screen leaves room for — the page scrolls its middle once capped.
local function panelFrame()
  local item = menu:frame()
  local screen = hs.screen.mainScreen():fullFrame()
  local x = item.x + item.w / 2 - PANEL_WIDTH / 2
  local y = item.y + item.h + MENUBAR_GAP
  local leftLimit = screen.x + SCREEN_MARGIN - PANEL_SIDE_MARGIN
  local rightLimit = screen.x + screen.w - PANEL_WIDTH - SCREEN_MARGIN + PANEL_SIDE_MARGIN
  local availableHeight = screen.y + screen.h - y - SCREEN_MARGIN

  return {
    x = math.max(leftLimit, math.min(x, rightLimit)),
    y = y,
    w = PANEL_WIDTH,
    h = math.min(panelHeight, availableHeight),
  }
end

-- Close the panel and stop listening for clicks and Escape.
function M.hide()
  if not panelVisible then
    return
  end

  panelVisible = false
  sendCommand("idle")
  limitColorTimer:stop()
  outsideTap:stop()
  escapeTap:stop()
  webview:evaluateJavaScript("window.claudeStats.setVisible(false)")
  webview:hide()
end

-- Open the panel under the item with the lines from the last open, and have
-- the helper read every source now and keep reading while it is open.
function M.show()
  panelVisible = true

  sendCommand("live")
  webview:frame(panelFrame())

  if pageReady then
    pushLimitColors()

    if latestSessionsLine ~= nil then
      pushToPanel(latestSessionsLine)
    end

    webview:evaluateJavaScript("window.claudeStats.setVisible(true)")
  end

  webview:show()
  limitColorTimer:start()
  outsideTap:start()
  escapeTap:start()
end

-- The item click: open the panel, or close it when it is already open.
function M.toggle()
  if panelVisible then
    M.hide()

    return
  end

  M.show()
end

-- Where the panel window sits, for capturing it from the shell.
function M.frame()
  return webview:frame()
end

-- What the bar shows now: idle, busy, waiting, busyWaiting or away.
function M.barState()
  return barState
end

-- Kill the helper and start a fresh one.
function M.restart()
  lineStream.stop(task)
  task = nil
  startHelper()
end

-- Bring a session's terminal forward. The script switches tmux to the
-- session's pane when there is one and prints the processes to try, nearest
-- first; the first that is an app gets activated. A tmux switch is announced
-- by a leading "back <client pane> <session pane>" line, which arms Cmd+K's
-- return before activation, while the app to return to is still in front.
-- Nothing found means the session runs somewhere without a window, and its
-- folder opens instead — ClaudeBar's fallback.
local function focusSession(pid, cwd)
  -- Arm Cmd+K, then activate the first printed pid that is an app, else
  -- open the folder.
  local function activateFirstApp(_, stdout, _)
    local output = "\n" .. (stdout or "")
    local clientPane, sessionPane = output:match("^\nback (%S+) (%S+)\n")

    if sessionPane ~= nil then
      notifyReturn.capture(clientPane, sessionPane)
    end

    -- Whole-line numbers only, so the pane ids on the back line are skipped.
    for candidate in output:gmatch("\n(%d+)") do
      local app = hs.application.applicationForPID(tonumber(candidate))

      if app ~= nil then
        app:activate()

        return
      end
    end

    if cwd ~= nil and cwd ~= "" then
      hs.task.new("/usr/bin/open", nil, { cwd }):start()
    end
  end

  hs.task.new(FOCUS_SCRIPT, activateFirstApp, { tostring(pid) }):start()
end

-- What the page asks for: a new height, a session to focus, a folder to open.
local function handlePanelMessage(message)
  local body = message.body

  if type(body) ~= "table" then
    return
  end

  if body.action == "resize" and tonumber(body.height) ~= nil then
    panelHeight = tonumber(body.height)

    if panelVisible then
      webview:frame(panelFrame())
    end
  elseif body.action == "focus" and tonumber(body.pid) ~= nil then
    M.hide()
    focusSession(tonumber(body.pid), body.cwd)
  elseif body.action == "reveal" and type(body.cwd) == "string" and body.cwd ~= "" then
    M.hide()
    hs.task.new("/usr/bin/open", nil, { body.cwd }):start()
  end
end

-- The profiles as the page needs them, as a JavaScript literal.
local function profilesLiteral()
  local list = {}

  for _, profile in ipairs(PROFILES) do
    list[#list + 1] = { name = profile.name, label = profile.label, title = profile.title }
  end

  return hs.json.encode(list)
end

-- Once the page has loaded, hand it the profiles and whatever already came.
local function handleNavigation(action)
  if action ~= "didFinishNavigation" then
    return
  end

  pageReady = true
  webview:evaluateJavaScript("window.claudeStats.configure(" .. profilesLiteral() .. ")")

  if panelVisible then
    M.show()
  end
end

-- Dismiss on any click that is not on the panel, passing the click through
-- so dismissing and clicking what is behind are one gesture — except on the
-- item itself, where the click is swallowed so it does not open the panel
-- straight back (the same rule canvas_panel.lua follows).
local function handleClickOutside(event)
  local point = event:location()

  if containsPoint(webview:frame(), point) then
    return false
  end

  M.hide()

  return containsPoint(menu:frame(), point)
end

-- Escape closes the panel and is swallowed; closing is all it meant.
local function handleEscape(event)
  if event:getKeyCode() ~= ESCAPE_KEY_CODE then
    return false
  end

  M.hide()

  return true
end

-- The page, loaded once and kept: shown and hidden rather than rebuilt, so
-- the range and profile picked in it survive between opens.
local function buildPanel()
  local controller = hs.webview.usercontent.new("claudeStats")

  controller:setCallback(handlePanelMessage)

  webview = hs.webview.new({ x = 0, y = 0, w = PANEL_WIDTH, h = panelHeight }, {}, controller)
  webview:windowStyle({ "borderless", "nonactivating" })
  webview:transparent(true)
  webview:shadow(false)
  webview:allowTextEntry(false)
  webview:level(hs.drawing.windowLevels.popUpMenu)

  -- Follows whichever Space is in front each time it opens. canJoinAllSpaces
  -- does not hold for a webview kept between opens: the window stays on the
  -- Space it was first shown on, and clicking the item anywhere else opened
  -- it there, out of sight. fullScreenAuxiliary lets it over a full-screen app.
  webview:behavior(hs.drawing.windowBehaviors.moveToActiveSpace
    + hs.drawing.windowBehaviors.fullScreenAuxiliary
  )
  webview:navigationCallback(handleNavigation)
  webview:url("file://" .. PANEL_PAGE)
end

-- A reload tears down this Lua state without necessarily stopping the
-- previous helper. Anchored to the helper's own path at the start of the
-- command line, so a shell or editor merely mentioning it is spared.
hs.execute("/usr/bin/pkill -f '^" .. HELPER .. " watch'")

menu = hs.menubar.new(true, "claudeStats")
showLook(LOOKS.idle)
menu:setClickCallback(M.toggle)
spinnerTimer = hs.timer.new(SPINNER_SECONDS, turnSpinner)

buildPanel()

outsideTap = hs.eventtap.new({
  hs.eventtap.event.types.leftMouseDown,
  hs.eventtap.event.types.rightMouseDown,
  hs.eventtap.event.types.otherMouseDown,
}, handleClickOutside
)
escapeTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, handleEscape)

startHelper()
supervisorTimer = hs.timer.doEvery(SUPERVISOR_SECONDS, startHelper)
limitColorTimer = hs.timer.new(LIMIT_COLOR_SECONDS, pushLimitColors)

_G[INSTANCE_KEY] = M

return M
