-- A dropdown panel hanging off a menubar item, drawn into an hs.canvas the
-- widget owns rather than into a native menu.
--
-- Owning the surface is what buys a panel that updates while it is on screen.
-- A native NSMenu runs a modal event loop while it is tracking — Hammerspoon's
-- timers do not fire during it, and hs.menubar hands out no reference to an
-- item already open — so a menu can only ever show the readings it was built
-- with. The cost is the dismissal a menu gives away for free, so a click
-- outside, Escape, and a second click on the icon are all wired up here.
--
-- Shared because two menubar items want the same live dropdown for different
-- readings. What the caller owns is `buildSections(resting)`: the readings of
-- the moment as stat_panel sections. It is called on open and then on the
-- refresh cadence, and only while the panel is visible.
--
-- Usage:
--   local canvasPanel = require("canvas_panel")
--   local panel = canvasPanel.new(menu, 1, buildSections)
--   menu:setClickCallback(panel.toggle)

local statPanel = require("stat_panel")

local M = {}

-- The panel pays back stat_panel's lopsided margin, which exists only to
-- cancel the indent AppKit gives a menu item's image. Nothing indents this
-- one.
local PANEL_INSET = statPanel.EVEN_MARGIN_INSET
local PANEL_WIDTH = statPanel.WIDTH + PANEL_INSET
local PANEL_RADIUS = 6

-- Clear of the menubar, and clear of the screen edge if the icon sits far
-- enough right that the panel would hang off it.
local MENUBAR_GAP = 2
local SCREEN_MARGIN = 8

-- The surface behind the rows, matched to a native menu as closely as a canvas
-- can be: the radius and the wash are the menu's, but not the material. AppKit
-- blurs what is behind a menu through an NSVisualEffectView, and hs.canvas has
-- no such element — so this is a near-opaque wash in the appearance of the
-- moment, which is the one visible difference from a native dropdown.
local DARK_SURFACE = { white = 0.14, alpha = 0.98 }
local LIGHT_SURFACE = { white = 0.97, alpha = 0.98 }
local BORDER_ALPHA = 0.16
local BORDER_WIDTH = 1

local ESCAPE_KEY_CODE = hs.keycodes.map.escape

local function surfaceColor()
  if hs.host.interfaceStyle() == "Dark" then
    return DARK_SURFACE
  end

  return LIGHT_SURFACE
end

-- The rounded wash and its hairline, under everything the rows draw.
local function surfaceElements(height, resting)
  return {
    {
      type = "rectangle",
      action = "fill",
      fillColor = surfaceColor(),
      roundedRectRadii = { xRadius = PANEL_RADIUS, yRadius = PANEL_RADIUS },
      frame = { x = 0, y = 0, w = PANEL_WIDTH, h = height },
    },
    {
      type = "rectangle",
      action = "stroke",
      strokeColor = statPanel.faded(resting, BORDER_ALPHA),
      strokeWidth = BORDER_WIDTH,
      roundedRectRadii = { xRadius = PANEL_RADIUS, yRadius = PANEL_RADIUS },
      -- Inset by half a point so the stroke lands inside the canvas instead of
      -- straddling its edge and coming out half as bright.
      frame = {
        x = BORDER_WIDTH / 2,
        y = BORDER_WIDTH / 2,
        w = PANEL_WIDTH - BORDER_WIDTH,
        h = height - BORDER_WIDTH,
      },
    },
  }
end

local function containsPoint(frame, point)
  return point.x >= frame.x and point.x <= frame.x + frame.w
    and point.y >= frame.y and point.y <= frame.y + frame.h
end

-- One panel under one menubar item. Created once and reused: the panel is
-- shown and hidden rather than built and thrown away, so the window it lives
-- in keeps its place in the level order.
function M.new(menu, refreshSeconds, buildSections)
  -- Created at the panel width and squared off; the height it actually needs
  -- is only known once the rows have been laid out.
  local canvas = hs.canvas.new({ x = 0, y = 0, w = PANEL_WIDTH, h = PANEL_WIDTH })
  local panel = {}
  local refreshTimer = nil
  local outsideTap = nil
  local escapeTap = nil
  local visible = false

  -- Set when the panel was dismissed by a click that landed on the icon, so
  -- the menubar callback that follows does not read it as a request to open
  -- again.
  local dismissedByIcon = false

  -- Plain text of what was last drawn, for reading the panel from `hs -c`
  -- without opening it.
  local lastText = ""

  -- Where the panel hangs: under the icon and left-aligned to it, the way a
  -- menu would, pulled back inside the screen when the icon sits far enough
  -- right that the panel would overhang.
  local function panelOrigin()
    local item = menu:frame()
    local screen = hs.screen.mainScreen():fullFrame()
    local rightLimit = screen.x + screen.w - PANEL_WIDTH - SCREEN_MARGIN

    return math.max(screen.x + SCREEN_MARGIN, math.min(item.x, rightLimit)),
      item.y + item.h + MENUBAR_GAP
  end

  -- Take a reading and repaint. Called once on open and then on the timer,
  -- which only runs while the panel is up.
  local function repaint()
    local resting = statPanel.textColor()
    local sections = buildSections(resting)

    lastText = statPanel.stackText(sections)

    local rows, height = statPanel.stack(sections, resting, PANEL_INSET)
    local elements = surfaceElements(height, resting)

    for _, row in ipairs(rows) do
      elements[#elements + 1] = row
    end

    local x, y = panelOrigin()

    canvas:frame({ x = x, y = y, w = PANEL_WIDTH, h = height })
    canvas:replaceElements(table.unpack(elements))
  end

  function panel.hide()
    if not visible then
      return
    end

    visible = false
    refreshTimer:stop()
    outsideTap:stop()
    escapeTap:stop()
    canvas:hide()
  end

  function panel.show()
    visible = true

    repaint()
    canvas:show()
    refreshTimer:start()
    outsideTap:start()
    escapeTap:start()
  end

  function panel.toggle()
    if dismissedByIcon then
      dismissedByIcon = false

      return
    end

    if visible then
      panel.hide()

      return
    end

    panel.show()
  end

  -- Plain text of what the panel last drew. Takes a fresh reading when the
  -- panel has never been opened, so it answers on a cold config too.
  function panel.text()
    if lastText == "" then
      repaint()
    end

    return lastText
  end

  -- Dismiss on any click that is not on the panel. The click is passed through
  -- rather than swallowed, so dismissing the panel and clicking what is behind
  -- it are one gesture.
  local function handleClickOutside(event)
    local point = event:location()

    if containsPoint(canvas:frame(), point) then
      return false
    end

    -- A click on the icon reaches this tap before the menubar callback.
    -- Without the flag the callback would read the panel as already shut and
    -- open it straight back, so the icon would never close it.
    if containsPoint(menu:frame(), point) then
      dismissedByIcon = true
    end

    panel.hide()

    return false
  end

  -- Escape is swallowed, because dismissing a panel is the whole of what the
  -- keystroke meant.
  local function handleEscape(event)
    if event:getKeyCode() ~= ESCAPE_KEY_CODE then
      return false
    end

    panel.hide()

    return true
  end

  refreshTimer = hs.timer.new(refreshSeconds, repaint)
  outsideTap = hs.eventtap.new({
    hs.eventtap.event.types.leftMouseDown,
    hs.eventtap.event.types.rightMouseDown,
    hs.eventtap.event.types.otherMouseDown,
  }, handleClickOutside)
  escapeTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, handleEscape)

  -- Above ordinary windows and clear of the menubar, and present on whichever
  -- Space is in front — the panel belongs to the bar, not to a desktop.
  canvas:level(hs.canvas.windowLevels.popUpMenu)
  canvas:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces
    + hs.canvas.windowBehaviors.stationary)

  return panel
end

return M
