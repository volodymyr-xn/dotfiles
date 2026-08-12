-- Keep-awake toggle: holds a "systemIdle" power assertion so the machine
-- never idle-sleeps, and suppresses lid-close sleep via
-- `pmset disablesleep`. Equivalent to `caffeinate -i`, plus the clamshell
-- part it cannot do. The display still sleeps and locks on its normal
-- schedule — only the system is kept running.
--
-- Deliberately not persisted: every Hammerspoon reload/restart starts OFF,
-- so a forgotten assertion can never keep the Mac awake indefinitely.
--
-- The lid-close half needs the passwordless sudo rule from
-- macos/sudoers.d/pmset-disablesleep; without it the assertion still applies
-- and the banner says so, rather than the toggle failing outright.

local canvasBanner = require("canvas_banner")

-- Assertion type held while enabled. "systemIdle" lets the display go dark
-- and lock while the system stays up; "displayIdle" would also block display
-- sleep and therefore the screen lock, and "system" only works on AC power.
local SLEEP_TYPE = "systemIdle"

-- true applies the assertion on battery as well, not just on AC power.
local APPLY_ON_BATTERY = true

-- Wrapper owning the root-only `pmset -a disablesleep` call. Absolute path
-- because Hammerspoon's hs.execute uses a non-login shell whose PATH does
-- not include ~/dotfiles/bin.
local LID_SLEEP_SCRIPT = os.getenv("HOME") .. "/dotfiles/bin/c-macos-toggle-lid-sleep"

-- Exit code the wrapper returns when the sudoers rule is missing.
local EXIT_NO_SUDO = 77

-- nf-md-coffee / nf-md-sleep — glyph fallback for the banner when the
-- SVG artwork cannot be loaded.
local ICON_ON = "󰅶"
local ICON_OFF = "󰒲"

-- Artwork; SVG so it stays crisp on Retina at any size.
local IMAGE_ON = hs.image.imageFromPath(hs.configdir .. "/assets/coffee.svg")
local IMAGE_OFF = hs.image.imageFromPath(hs.configdir .. "/assets/sleep.svg")

-- Fits the 24pt menubar with the standard couple of points of breathing room.
local MENUBAR_ICON_SIZE = 18

-- Separate artwork for the menubar: solid saturated shapes, because the
-- banner's thin outline strokes disappear at this size. Scaled once at load
-- rather than on every toggle.
local MENUBAR_ICON = hs.image
  .imageFromPath(hs.configdir .. "/assets/coffee_menubar.svg")
  :setSize({ w = MENUBAR_ICON_SIZE, h = MENUBAR_ICON_SIZE })

local menu = hs.menubar.new()

-- Show the coffee cup only while keep-awake is active; normal sleep is the
-- default state, so it claims no menubar space at all. Read from
-- hs.caffeinate.get so the live assertion is the single source of truth
-- (never a cached boolean that can drift).
--
-- template = false keeps the SVG's own orange: the default (true) treats the
-- image as a mask and paints it in the menubar's own black/white tint.
local function refreshIcon()
  if hs.caffeinate.get(SLEEP_TYPE) then
    menu:returnToMenuBar()
    menu:setIcon(MENUBAR_ICON, false)
  else
    menu:removeFromMenuBar()
  end
end

-- Ask the wrapper to suppress or restore lid-close sleep. Returns true when
-- the setting was applied; false means the sudoers rule is missing, which is
-- reported in the banner instead of aborting the toggle.
local function setLidSleep(verb)
  local _, _, _, exitCode =
    hs.execute(string.format("%q %s", LID_SLEEP_SCRIPT, verb))

  return exitCode ~= EXIT_NO_SUDO
end

-- Flip the assertion and surface the new state via the shared banner.
local function toggle()
  local keepAwake = not hs.caffeinate.get(SLEEP_TYPE)
  hs.caffeinate.set(SLEEP_TYPE, keepAwake, APPLY_ON_BATTERY)

  local lidCovered = setLidSleep(keepAwake and "prevent" or "allow")

  refreshIcon()

  local subtitle

  if not lidCovered then
    subtitle = "System sleep only — sudo rule missing"
  elseif keepAwake then
    subtitle = "System + lid-close sleep blocked"
  else
    subtitle = "Normal sleep schedule restored"
  end

  canvasBanner.show({
    title = keepAwake and "No sleep" or "Will sleep...",
    subtitle = subtitle,
    state = keepAwake and "on" or "off",
    image = keepAwake and IMAGE_ON or IMAGE_OFF,
    icon = keepAwake and ICON_ON or ICON_OFF,
  })
end

-- Release both halves on reload so the outgoing instance never leaks a
-- suppressed lid or a held assertion.
hs.caffeinate.set(SLEEP_TYPE, false, APPLY_ON_BATTERY)
setLidSleep("allow")

menu:setClickCallback(toggle)
refreshIcon()

return {
  toggle = toggle,
  isEnabled = function() return hs.caffeinate.get(SLEEP_TYPE) end,
}
