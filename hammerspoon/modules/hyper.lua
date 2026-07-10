-- The two physical Control keys as a true Hyper modifier: holding either one
-- rewrites the accompanying keystroke to a real Cmd+Alt+Ctrl+Shift chord, so
-- any app can bind it — Raycast, app preferences, nvim — not just this
-- config.
--
-- "Physical" matters because the external USB Keyboard (6700-8484) carries a
-- per-device modifier remap, readable via:
--   defaults -currentHost read -g | grep -A20 modifiermapping
-- Measured keycodes (tap flagsChanged and log getKeyCode() to re-verify on a
-- new keyboard — the stored prefs are per vendor/product id):
--   physical left Ctrl   → left Option    keycode 58, flag alt
--   physical right Ctrl  → right Option   keycode 61, flag alt
--   physical Caps Lock   → right Control  keycode 62, flag ctrl
--   physical left/right Option → Command  (so 58 and 61 have no other source)
--
-- Two consequences drive the design. Keycode 62 must be left untouched or
-- Caps Lock stops sending Control to tmux/shell/nvim. And hs.hotkey can only
-- match on the modifier flag — which the remapped Ctrl keys share with real
-- Option — so this taps flagsChanged and matches the raw keycode instead.
--
-- Each keycode is paired with the flag it actually toggles; the pair must
-- stay in sync, since 58/61 are Option keycodes and so raise `alt`, not
-- `ctrl`. On the built-in keyboard these same keycodes are genuine Option
-- keys, which therefore act as Hyper there — drop an entry to get one back.
local HYPER_KEYS = {
  [58] = "alt",
  [61] = "alt",
}

-- Exported for keys.lua: hs.hotkey.bind(hyper.modifiers, "t", fn).
local HYPER_MODIFIERS = { "cmd", "alt", "ctrl", "shift" }

-- The same set in the keyed shape hs.eventtap.event:setFlags() expects.
local HYPER_FLAGS = { cmd = true, alt = true, ctrl = true, shift = true }

-- Tracks whether a Hyper key is currently held, since the keyDown branch
-- below cannot read it off the event (the flagsChanged event that would have
-- carried it is swallowed before macOS ever sees it).
local isHyperHeld = false

-- flagsChanged: enter/leave the held state and swallow the event (return
-- true) so macOS never receives Option from these keys — a bare Hyper press
-- must produce nothing at all.
--
-- keyDown/keyUp: while held, overwrite the flags with the full Hyper set and
-- return false so the *modified* event propagates. Rewriting in place rather
-- than posting a synthetic keyStroke keeps the original keycode, autorepeat,
-- and target app intact, and needs no per-key declaration — every key works.
--
-- Known edge case: getFlags() reports the aggregate modifier state, so
-- releasing one Hyper key while the other (or a real Option) is held reads
-- as still-down and leaves Hyper stuck on. Self-correcting on the next tap.
local function handle(event)
  if event:getType() == hs.eventtap.event.types.flagsChanged then
    local flag = HYPER_KEYS[event:getKeyCode()]

    if not flag then return false end

    isHyperHeld = event:getFlags()[flag] == true

    return true
  end

  if isHyperHeld then
    event:setFlags(HYPER_FLAGS)
  end

  return false
end

-- Module-local keeps the tap alive for the module's lifetime (Lua caches
-- required modules, so this upvalue survives garbage collection).
local eventTypes = hs.eventtap.event.types
local tap = hs.eventtap.new(
  { eventTypes.flagsChanged, eventTypes.keyDown, eventTypes.keyUp },
  handle
)
tap:start()

return {
  modifiers = HYPER_MODIFIERS,
  tap = tap,
}
