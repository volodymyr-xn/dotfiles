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
--     icon = "󰅶",    -- optional Nerd Font glyph, replaces the status dot
--     image = hs.image.imageFromAppBundle("com.apple.Safari"),
--                    -- optional hs.image, wins over icon and the dot
--   })
--
-- Sources for `image`: hs.image.imageFromPath("~/pics/x.png"),
-- hs.image.imageFromAppBundle(bundleID), hs.image.imageFromName("Computer")
-- (NSImage names, see hs.image.systemImageNames). SF Symbol names are not
-- resolvable by this Hammerspoon build.

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

-- Slide-in + fade timings. The canvas fades natively via show()/hide();
-- the horizontal travel is stepped by a timer since hs.canvas has no
-- built-in position animation.
local FADE_IN = 0.12
local FADE_OUT = 0.18
local SLIDE_DISTANCE = 14
local SLIDE_STEPS = 8
local SLIDE_INTERVAL = 0.014

local COLOR_SURFACE_TOP = { hex = "#242426", alpha = 0.97 }
local COLOR_SURFACE_BOTTOM = { hex = "#171719", alpha = 0.97 }
local COLOR_BORDER = { hex = "#ffffff", alpha = 0.06 }
local COLOR_TOP_EDGE = { hex = "#ffffff", alpha = 0.14 }
local COLOR_SHADOW = { hex = "#000000", alpha = 0.45 }
local COLOR_TITLE = { hex = "#f5f5f7" }
local COLOR_SUBTITLE = { hex = "#8e8e93" }
local COLOR_DOT_ON = { hex = "#34c759" }
local COLOR_DOT_OFF = { hex = "#8e8e93" }
local COLOR_GLOW_ON = { hex = "#34c759", alpha = 0.28 }

local TITLE_SIZE = 15
local SUBTITLE_SIZE = 12.5

-- PostScript name of the installed Nerd Font; the system UI font has no
-- glyphs in the private-use range, so icons render as tofu without this.
local ICON_FONT = "JetBrainsMonoNF-Regular"
local ICON_SIZE = 30

-- Bounding box for a real hs.image marker; scaled proportionally inside it.
local IMAGE_SIZE = 40

-- Horizontal gap between the artwork's right edge and the title text.
local IMAGE_GAP = 10

-- Inset from the card's left edge to the artwork.
local IMAGE_MARGIN = 20

-- Re-exported so other modules (menubar titles, etc.) style Nerd Font
-- glyphs with the same font and on/off colors instead of redefining them.
M.ICON_FONT = ICON_FONT
M.COLOR_ON = COLOR_DOT_ON
M.COLOR_OFF = COLOR_DOT_OFF
M.COLOR_ALERT = { hex = "#ff9f0a" }

-- Shared state so a new banner replaces the previous one instead of
-- stacking; every timer is tracked so it can be cancelled when re-shown.
local live = {
  canvas = nil,
  hideTimer = nil,
  slideTimer = nil,
  deleteTimer = nil,
}

-- Stop and forget every live timer; safe to call when none are running.
local function stopTimers()
  for _, key in ipairs({ "hideTimer", "slideTimer", "deleteTimer" }) do
    local timer = live[key]

    if timer then
      timer:stop()
      live[key] = nil
    end
  end
end

-- Tear the banner down immediately, with no fade. Used when a new banner
-- replaces the current one, where a fade would read as a flicker.
local function dismiss()
  stopTimers()

  if live.canvas then
    live.canvas:delete()
    live.canvas = nil
  end
end

-- Fade the banner out, then delete it once the fade has finished. Used for
-- the auto-dismiss timeout, where the disappearance should be visible.
local function fadeOut()
  if not live.canvas then return end

  local canvas = live.canvas

  stopTimers()
  canvas:hide(FADE_OUT)

  live.deleteTimer = hs.timer.doAfter(FADE_OUT, function()
    live.deleteTimer = nil

    if live.canvas == canvas then
      canvas:delete()
      live.canvas = nil
    end
  end)
end

M.dismiss = dismiss

-- Ease-out cubic: fast entry, soft landing — the shape macOS uses for
-- notification slides.
local function easeOut(progress)
  local inverse = 1 - progress

  return 1 - inverse * inverse * inverse
end

-- Walk the canvas from its offscreen-right start position to targetX.
local function slideIn(canvas, targetX, y)
  local step = 0

  live.slideTimer = hs.timer.doEvery(SLIDE_INTERVAL, function()
    step = step + 1

    local eased = easeOut(step / SLIDE_STEPS)
    canvas:topLeft({ x = targetX + SLIDE_DISTANCE * (1 - eased), y = y })

    if step >= SLIDE_STEPS then
      canvas:topLeft({ x = targetX, y = y })

      if live.slideTimer then
        live.slideTimer:stop()
        live.slideTimer = nil
      end
    end
  end)
end

-- Draw the banner top-right of the main screen with an optional status
-- marker: a real image when `image` is given, else a Nerd Font glyph when
-- `icon` is given, else a status dot.
-- opts: {
--   title = string, subtitle = string?,
--   state = "on"|"off"|nil, icon = string?, image = hs.image?,
-- }
function M.show(opts)
  dismiss()

  local title = opts.title
  local subtitle = opts.subtitle
  local stateKey = opts.state
  local icon = opts.icon
  local image = opts.image
  local hasState = stateKey == "on" or stateKey == "off"
  local hasArtwork = image ~= nil or icon ~= nil
  local hasDot = hasState and not hasArtwork
  local active = stateKey == "on"
  local accentColor = active and COLOR_DOT_ON or COLOR_DOT_OFF

  local frame = hs.screen.mainScreen():frame()
  local x = frame.x + frame.w - CARD_W - SCREEN_MARGIN - SHADOW_PAD
  local y = frame.y + SCREEN_MARGIN - SHADOW_PAD

  local c = hs.canvas.new({
    x = x + SLIDE_DISTANCE,
    y = y,
    w = CANVAS_W,
    h = CANVAS_H,
  })
  c:level(hs.canvas.windowLevels.screenSaver)
  c:behavior({ "canJoinAllSpaces", "stationary" })

  local cardFrame = { x = SHADOW_PAD, y = SHADOW_PAD, w = CARD_W, h = CARD_H }
  local dotSize = 10
  local dotCenterX = SHADOW_PAD + 22
  local centerY = SHADOW_PAD + CARD_H / 2
  local artworkLeft = SHADOW_PAD + IMAGE_MARGIN
  local artworkCenterX = artworkLeft + IMAGE_SIZE / 2
  local textLeft = SHADOW_PAD + 20

  if hasArtwork then
    textLeft = artworkLeft + IMAGE_SIZE + IMAGE_GAP
  elseif hasState then
    textLeft = dotCenterX + dotSize / 2 + 14
  end

  local textWidth = CARD_W - (textLeft - SHADOW_PAD) - 18

  local i = 0
  local function add(element)
    i = i + 1
    c[i] = element

    return i
  end

  add({
    type = "rectangle",
    action = "fill",
    fillGradient = "linear",
    fillGradientAngle = 90,
    fillGradientColors = { COLOR_SURFACE_TOP, COLOR_SURFACE_BOTTOM },
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
    strokeColor = COLOR_BORDER,
    strokeWidth = 1,
    roundedRectRadii = { xRadius = CORNER_RADIUS, yRadius = CORNER_RADIUS },
    frame = {
      x = cardFrame.x + 0.5,
      y = cardFrame.y + 0.5,
      w = cardFrame.w - 1,
      h = cardFrame.h - 1,
    },
  })

  -- Brighter hairline across the top edge only: mimics light catching the
  -- upper bevel, which a uniform border stroke cannot express.
  add({
    type = "segments",
    action = "stroke",
    strokeColor = COLOR_TOP_EDGE,
    strokeWidth = 1,
    coordinates = {
      { x = cardFrame.x + CORNER_RADIUS, y = cardFrame.y + 0.5 },
      { x = cardFrame.x + CARD_W - CORNER_RADIUS, y = cardFrame.y + 0.5 },
    },
  })

  if hasDot then
    if active then
      add({
        type = "circle",
        action = "fill",
        fillColor = COLOR_GLOW_ON,
        center = { x = dotCenterX, y = centerY },
        radius = dotSize / 2 + 4,
      })
    end

    add({
      type = "circle",
      action = "fill",
      fillColor = accentColor,
      center = { x = dotCenterX, y = centerY },
      radius = dotSize / 2,
    })
  end

  if image then
    add({
      type = "image",
      image = image,
      imageScaling = "scaleProportionally",
      imageAlignment = "center",
      frame = {
        x = artworkLeft,
        y = centerY - IMAGE_SIZE / 2,
        w = IMAGE_SIZE,
        h = IMAGE_SIZE,
      },
    })
  elseif icon then
    add({
      type = "text",
      text = icon,
      textColor = accentColor,
      textSize = ICON_SIZE,
      textFont = ICON_FONT,
      textAlignment = "center",
      frame = {
        x = artworkCenterX - IMAGE_SIZE,
        y = centerY - ICON_SIZE * 0.72,
        w = IMAGE_SIZE * 2,
        h = ICON_SIZE * 1.5,
      },
    })
  end

  local titleY = subtitle
    and (SHADOW_PAD + 22)
    or (SHADOW_PAD + (CARD_H - 20) / 2)

  add({
    type = "text",
    text = title,
    textColor = COLOR_TITLE,
    textSize = TITLE_SIZE,
    textFont = ".AppleSystemUIFontBold",
    textLineBreak = "truncateTail",
    frame = { x = textLeft, y = titleY, w = textWidth, h = 20 },
  })

  if subtitle then
    add({
      type = "text",
      text = subtitle,
      textColor = COLOR_SUBTITLE,
      textSize = SUBTITLE_SIZE,
      textFont = ".AppleSystemUIFont",
      textLineBreak = "truncateTail",
      frame = {
        x = textLeft,
        y = SHADOW_PAD + 44,
        w = textWidth,
        h = 18,
      },
    })
  end

  c:show(FADE_IN)
  live.canvas = c

  slideIn(c, x, y)

  live.hideTimer = hs.timer.doAfter(DURATION, fadeOut)
end

return M
