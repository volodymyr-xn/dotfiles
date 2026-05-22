-- Reusable Notification-Center-style banner rendered with hs.canvas.
-- Canvas windows are not routed through Notification Center, so macOS
-- Game Mode / Focus modes cannot suppress them.
--
-- Usage:
--   local banner = require("canvas_banner")
--   banner.show({
--     title = "Side buttons: ON",
--     subtitle = "Hammerspoon mappings active",
--     state = "on",  -- "on" | "off" | nil (omit to skip the status dot)
--   })

local M = {}

-- Visible card dimensions; canvas itself is larger so the drop shadow
-- has room to render without clipping at the card edges.
local CARD_W = 340
local CARD_H = 84
local SHADOW_PAD = 24
local CANVAS_W = CARD_W + SHADOW_PAD * 2
local CANVAS_H = CARD_H + SHADOW_PAD * 2
local SCREEN_MARGIN = 12
local DURATION = 1.8
local CORNER_RADIUS = 14

local COLOR_SURFACE = { hex = "#1c1c1e", alpha = 0.95 }
local COLOR_HIGHLIGHT = { hex = "#ffffff", alpha = 0.10 }
local COLOR_SHADOW = { hex = "#000000", alpha = 0.45 }
local COLOR_TITLE = { hex = "#f5f5f7" }
local COLOR_SUBTITLE = { hex = "#9999a0" }
local COLOR_DOT_ON = { hex = "#34c759" }
local COLOR_DOT_OFF = { hex = "#8e8e93" }
local COLOR_GLOW_ON = { hex = "#34c759", alpha = 0.28 }

-- Shared state so a new banner replaces the previous one instead of
-- stacking; the dismiss timer can be cancelled when re-shown.
local live = { canvas = nil, hideTimer = nil }

-- Tear down the live banner canvas + timer; safe to call when neither exists.
local function dismiss()
  if live.hideTimer then
    live.hideTimer:stop()
    live.hideTimer = nil
  end

  if live.canvas then
    live.canvas:delete()
    live.canvas = nil
  end
end

M.dismiss = dismiss

-- Draw the banner top-right of the main screen with optional status dot.
-- opts: { title = string, subtitle = string?, state = "on"|"off"|nil }
function M.show(opts)
  dismiss()

  local title = opts.title
  local subtitle = opts.subtitle
  local stateKey = opts.state
  local hasDot = stateKey == "on" or stateKey == "off"
  local active = stateKey == "on"

  local frame = hs.screen.mainScreen():frame()
  local x = frame.x + frame.w - CARD_W - SCREEN_MARGIN - SHADOW_PAD
  local y = frame.y + SCREEN_MARGIN - SHADOW_PAD

  local c = hs.canvas.new({ x = x, y = y, w = CANVAS_W, h = CANVAS_H })
  c:level(hs.canvas.windowLevels.screenSaver)
  c:behavior({ "canJoinAllSpaces", "stationary" })

  local cardFrame = { x = SHADOW_PAD, y = SHADOW_PAD, w = CARD_W, h = CARD_H }
  local dotSize = 10
  local dotCenterX = SHADOW_PAD + 22
  local dotCenterY = SHADOW_PAD + CARD_H / 2
  local textLeft = hasDot
    and (dotCenterX + dotSize / 2 + 14)
    or (SHADOW_PAD + 20)
  local textWidth = CARD_W - (textLeft - SHADOW_PAD) - 18

  local i = 0
  local function add(element)
    i = i + 1
    c[i] = element
  end

  add({
    type = "rectangle",
    action = "fill",
    fillColor = COLOR_SURFACE,
    roundedRectRadii = { xRadius = CORNER_RADIUS, yRadius = CORNER_RADIUS },
    frame = cardFrame,
    shadow = {
      blurRadius = 22,
      color = COLOR_SHADOW,
      offset = { h = -8, w = 0 },
    },
    withShadow = true,
  })

  add({
    type = "rectangle",
    action = "stroke",
    strokeColor = COLOR_HIGHLIGHT,
    strokeWidth = 1,
    roundedRectRadii = { xRadius = CORNER_RADIUS, yRadius = CORNER_RADIUS },
    frame = {
      x = cardFrame.x + 0.5,
      y = cardFrame.y + 0.5,
      w = cardFrame.w - 1,
      h = cardFrame.h - 1,
    },
  })

  if hasDot then
    if active then
      add({
        type = "circle",
        action = "fill",
        fillColor = COLOR_GLOW_ON,
        center = { x = dotCenterX, y = dotCenterY },
        radius = dotSize / 2 + 4,
      })
    end

    add({
      type = "circle",
      action = "fill",
      fillColor = active and COLOR_DOT_ON or COLOR_DOT_OFF,
      center = { x = dotCenterX, y = dotCenterY },
      radius = dotSize / 2,
    })
  end

  local titleY = subtitle
    and (SHADOW_PAD + 18)
    or (SHADOW_PAD + (CARD_H - 20) / 2)

  add({
    type = "text",
    text = title,
    textColor = COLOR_TITLE,
    textSize = 14,
    textFont = ".AppleSystemUIFontBold",
    frame = { x = textLeft, y = titleY, w = textWidth, h = 20 },
  })

  if subtitle then
    add({
      type = "text",
      text = subtitle,
      textColor = COLOR_SUBTITLE,
      textSize = 14,
      textFont = ".AppleSystemUIFont",
      frame = {
        x = textLeft,
        y = SHADOW_PAD + 42,
        w = textWidth,
        h = 28,
      },
    })
  end

  c:show()
  live.canvas = c
  live.hideTimer = hs.timer.doAfter(DURATION, dismiss)
end

return M
