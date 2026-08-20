-- Open the IPC Mach port so the `hs` CLI can drive this running instance.
-- Without this require, `hs -c "..."` (the CLI shipped with Hammerspoon)
-- has nothing to talk to — no Mach port is listening, so every shell-side
-- call fails silently or with "Hammerspoon is not running". This powers
-- `bin/c-hammerspoon-reload` and any other shell tooling that injects Lua
-- into the live config (debug one-liners, scripts that toggle features).
-- Kept at the very top so the port comes up even if a later require() in
-- this file blows up — otherwise a syntax error somewhere below would
-- lock us out of the CLI and force quitting/reopening the Hammerspoon
-- app to recover.
require("hs.ipc")

-- Generates EmmyLua type annotations for the whole `hs` API (and every
-- installed Spoon) into Spoons/EmmyLua.spoon/annotations on each reload.
-- hammerspoon/.luarc.json points lua-language-server at that directory, which
-- is what stops the editor reporting `hs` as an undefined global and gives
-- real completion/signatures instead. Editor-only: nothing at runtime depends
-- on it, so a missing Spoon must not break the config.
hs.loadSpoon("EmmyLua")

-- Hammerspoon only searches hs.configdir (and Spoons/) by default, so the
-- subdirectories have to be added to package.path before anything in them
-- can be require()d. Flat module names are kept — require("caffeine"), not
-- require("modules.caffeine") — so a file can move between modules/ and
-- lib/ without touching every call site. Also applies to `hs -c` one-liners,
-- which share this Lua state.
--   modules/ — self-contained features (one keybind or menubar item each)
--   lib/     — shared primitives with no bindings of their own
local searchPaths = {"modules", "lib"}

for _, dir in ipairs(searchPaths) do
  package.path = hs.configdir .. "/" .. dir .. "/?.lua;" .. package.path
end

-- Required here rather than left to config/keys.lua because loading them has
-- side effects beyond exposing a toggle: caffeine installs its menubar item,
-- mouse_side_buttons starts its eventtap, and system_stats installs its own
-- menubar item and refresh timer at require time.
require("caffeine")
require("mouse_side_buttons")

require("system_stats")
require("process_stats")

-- All global hotkey bindings.
require("keys")
