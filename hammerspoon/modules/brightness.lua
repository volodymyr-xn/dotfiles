local M = {}

-- m1ddc talks DDC/CI to the external panel over USB-C (DisplayPort Alt Mode).
-- Absolute path: Hammerspoon's PATH does not include Homebrew's bin.
local M1DDC = "/opt/homebrew/bin/m1ddc"

local STEP = 10

-- Top-right HUD: DDC changes bypass macOS entirely, so there is no native
-- OSD to piggyback on. hs.alert can only draw centred, hence a canvas.
local HUD_WIDTH = 172
local HUD_HEIGHT = 26
local HUD_MARGIN = 12
local HUD_DURATION = 0.8

-- Geometry of the progress line inside the HUD pill.
local GLYPH_WIDTH = 26
local VALUE_WIDTH = 40
local TRACK_HEIGHT = 4
local TRACK_X = GLYPH_WIDTH
local TRACK_WIDTH = HUD_WIDTH - GLYPH_WIDTH - VALUE_WIDTH - 6
local TRACK_Y = (HUD_HEIGHT - TRACK_HEIGHT) / 2

local hud = nil
local hudTimer = nil

-- Build the canvas lazily and reposition it every time, so the HUD follows
-- the display that is currently main after a monitor is plugged or unplugged.
local function ensureHud()
  local screenFrame = hs.screen.mainScreen():frame()
  local hudFrame = {
    x = screenFrame.x + screenFrame.w - HUD_WIDTH - HUD_MARGIN,
    y = screenFrame.y + HUD_MARGIN,
    w = HUD_WIDTH,
    h = HUD_HEIGHT,
  }

  if not hud then
    hud = hs.canvas.new(hudFrame)
    hud:level(hs.canvas.windowLevels.overlay)
    hud:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces)
    hud[1] = {
      type = "rectangle",
      action = "fill",
      fillColor = {white = 0, alpha = 0.75},
      roundedRectRadii = {xRadius = 8, yRadius = 8},
    }
    hud[2] = {
      type = "text",
      text = "󰃞",
      textAlignment = "center",
      textColor = {white = 1},
      -- Nerd Font face so the brightness glyph renders instead of tofu;
      -- hs.canvas defaults to a system font with no icon coverage.
      textFont = "CaskaydiaMonoNF-Regular",
      textSize = 14,
      frame = {x = 0, y = 3, w = GLYPH_WIDTH, h = HUD_HEIGHT},
    }
    hud[3] = {
      type = "rectangle",
      action = "fill",
      fillColor = {white = 1, alpha = 0.25},
      roundedRectRadii = {xRadius = 2, yRadius = 2},
      frame = {x = TRACK_X, y = TRACK_Y, w = TRACK_WIDTH, h = TRACK_HEIGHT},
    }
    hud[4] = {
      type = "rectangle",
      action = "fill",
      fillColor = {white = 1},
      roundedRectRadii = {xRadius = 2, yRadius = 2},
    }
    hud[5] = {
      type = "text",
      textAlignment = "right",
      textColor = {white = 1},
      textFont = "CaskaydiaMonoNF-Regular",
      textSize = 13,
      frame = {x = TRACK_X + TRACK_WIDTH, y = 4, w = VALUE_WIDTH - 8, h = HUD_HEIGHT},
    }
  end

  hud:frame(hudFrame)

  return hud
end

-- Flash the resulting level in the corner for a moment. The fill keeps a
-- minimum width so 0% still reads as a dot rather than vanishing.
local function showLevel(luminance)
  local canvas = ensureHud()
  canvas[4].frame = {
    x = TRACK_X,
    y = TRACK_Y,
    w = math.max(TRACK_HEIGHT, TRACK_WIDTH * luminance / 100),
    h = TRACK_HEIGHT,
  }
  canvas[5].text = luminance .. "%"

  canvas:show()

  if hudTimer then
    hudTimer:stop()
  end

  hudTimer = hs.timer.doAfter(HUD_DURATION, function()
    canvas:hide()
  end)
end

-- Snap to the next/previous multiple of STEP rather than adding a raw
-- delta, so a panel sitting on an odd value (6%) lands on 10/20/30 instead
-- of carrying the offset forever.
local function snapTarget(luminance, delta)
  local target

  if delta > 0 then
    target = (math.floor(luminance / STEP) + 1) * STEP
  else
    target = (math.ceil(luminance / STEP) - 1) * STEP
  end

  return math.max(0, math.min(100, target))
end

-- A non-zero exit means the display is asleep or DDC is unavailable, in
-- which case there is nothing truthful to show.
local function onSetExit(exitCode, stdOut, _stdErr)
  if exitCode ~= 0 then
    return
  end

  local luminance = tonumber(stdOut)

  if luminance then
    showLevel(luminance)
  end
end

-- Apply a relative brightness change (percentage points). Reading first is
-- required to snap onto the STEP grid; both calls run through hs.task
-- because a DDC round trip is 50-200ms and hs.execute would block the main
-- thread for that long on every keypress.
local function step(delta)
  local function onGetExit(exitCode, stdOut, _stdErr)
    local luminance = exitCode == 0 and tonumber(stdOut)

    if not luminance then
      return
    end

    local target = snapTarget(luminance, delta)

    hs.task.new(M1DDC, onSetExit, {"set", "luminance", tostring(target)}):start()
  end

  hs.task.new(M1DDC, onGetExit, {"get", "luminance"}):start()
end

-- Raise external display brightness by one step.
function M.up()
  step(STEP)
end

-- Lower external display brightness by one step.
function M.down()
  step(-STEP)
end

return M
