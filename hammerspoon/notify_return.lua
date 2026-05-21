local M = {}

-- Snapshots live next to the agent-notify watcher log so everything for this
-- feature shares one cache dir; they persist across reboots.
local CACHE_DIR = os.getenv("HOME") .. "/.cache/agent_notify"
local FULL_PATH = CACHE_DIR .. "/restore_full.json"
local GHOSTTY_BUNDLE = "com.mitchellh.ghostty"
-- Shared tmux-restore helper, on PATH via ~/dotfiles/bin (see bin/c-tmux-restore).
local TMUX_RESTORE_CMD = "c-tmux-restore"

-- True when `loc` is a usable tmux target: a pane id (%N, preferred) or a
-- session:window.pane string (the C_TMUX_BACK fallback shape).
local function isTmuxLoc(loc)
  if type(loc) ~= "string" then return false end

  return loc:match("^%%%d+$") ~= nil or loc:match("^.+:.+%..+$") ~= nil
end

-- Append one debug line so a real notification → restore is observable.
local function log(line)
  local f = io.open(CACHE_DIR .. "/watcher.log", "a")
  if not f then return end

  f:write(os.date("%H:%M:%S") .. " notify_return " .. line .. "\n")
  f:close()
end

-- Post a macOS Notification Center notification; optional `detail` becomes
-- the subtitle. Silent (no sound). Auto-withdraws after a few seconds.
local function notify(title, detail)
  local attrs = {
    title = title,
    withdrawAfter = 1,
  }

  if detail then attrs.subTitle = detail end

  hs.notify.new(attrs):send()
end

-- Single-quote `s` for safe use as one shell argument.
local function shellQuote(s)
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

-- Double-quote `s` as an AppleScript string literal.
local function asQuote(s)
  return '"' .. tostring(s):gsub("\\", "\\\\"):gsub('"', '\\"') .. '"'
end

-- Bring an app to the front via AppleScript `activate` (launches it if not
-- running). Tries the captured app name first, then the bundle id. Returns
-- whether either AppleScript call succeeded.
local function activateApp(name, bundle)
  local ok = false

  if name and name ~= "" then
    ok = hs.osascript.applescript(
      "tell application " .. asQuote(name) .. " to activate")
  end

  if not ok and bundle and bundle ~= "" then
    ok = hs.osascript.applescript(
      "tell application id " .. asQuote(bundle) .. " to activate")
  end

  return ok
end

-- True when the target app is already frontmost (i.e. any window of it is
-- the front window) — so no activation is needed; we only ever bring the
-- app forward, never a specific window. Compares by bundle id, else name.
local function isFrontmost(bundle, name)
  local front = hs.application.frontmostApplication()
  if not front then return false end

  if bundle and bundle ~= "" then
    return front:bundleID() == bundle
  end

  return name ~= nil and name ~= "" and front:name() == name
end

-- Write `data` to `path` atomically (tmp file + rename) so a concurrent
-- reader never sees a half-written file. Best-effort: false on any IO error.
local function writeJSON(path, data)
  os.execute("mkdir -p " .. shellQuote(CACHE_DIR) .. " 2>/dev/null")

  local encoded = hs.json.encode(data)
  if not encoded then return false end

  local tmp = path .. ".tmp"
  local file = io.open(tmp, "w")
  if not file then return false end

  file:write(encoded)
  file:close()

  return os.rename(tmp, path)
end

-- Read and decode `path`; nil when missing, empty, or invalid JSON.
local function readJSON(path)
  local file = io.open(path, "r")
  if not file then return nil end

  local contents = file:read("*a")
  file:close()

  if not contents or contents == "" then return nil end

  return hs.json.decode(contents)
end

-- Capture the user's pre-jump location before agent_notify forwards focus.
-- `tmuxLoc`   = the user's current tmux pane id (%N), "" / nil if not in tmux.
-- `agentPane` = the agent's pane id (the forward jump's target).
--
-- A tmux loc is a real return target only if it differs from the agent's
-- pane (else "go back" == "stay here"). If the user is *in Ghostty sitting
-- on the agent's pane*, the whole snapshot is a pure self-reference
-- (Ghostty + the agent pane) — skip writing so a prior, still-unused
-- return point survives. For any other app (e.g. Chrome) the app itself
-- IS a real return point, so always write the snapshot.
function M.capture(tmuxLoc, agentPane)
  local app = hs.application.frontmostApplication()

  local bundle = app and app:bundleID() or nil
  local isGhostty = bundle == GHOSTTY_BUNDLE

  if agentPane == "" then agentPane = nil end
  local sameAsAgent = isTmuxLoc(tmuxLoc) and tmuxLoc == agentPane
  local goodTmux = isTmuxLoc(tmuxLoc) and not sameAsAgent

  if isGhostty and sameAsAgent then
    log("capture: skip — in Ghostty at agent pane " .. tostring(tmuxLoc) ..
      " (keep prior snapshot)")
    return
  end

  -- App-level only: we restore by activating the app itself, never a
  -- specific window — so no window id is captured. Space is not captured
  -- either; macOS's `activate` handles the Space switch.
  local full = {
    app_name = app and app:name() or nil,
    app_bundle = bundle,
    is_ghostty = isGhostty,
    -- tmux loc only when captured in Ghostty AND it is a real (non-self) loc
    tmux = (isGhostty and goodTmux) and tmuxLoc or nil,
  }
  writeJSON(FULL_PATH, full)

  log(string.format(
    "capture: app=%s ghostty=%s tmuxLoc=%q agent=%s stored_tmux=%s",
    tostring(bundle), tostring(isGhostty),
    tostring(tmuxLoc), tostring(agentPane), tostring(full.tmux)))
end

-- Human-readable label for a tmux loc: "session window#pane".
-- For pane-id form (%N) queries tmux; for session:window.pane parses directly.
local function tmuxLocLabel(loc)
  local session, window, pane = loc:match("^(.+):(.+)%.(.+)$")

  if session then
    return session .. " " .. window .. "#" .. pane
  end

  local out = hs.execute(
    "tmux display-message -t " .. shellQuote(loc) ..
    " -p '#{session_name} #{window_name}##{pane_index}' 2>/dev/null", true)

  if out and out ~= "" then
    return out:gsub("%s+$", "")
  end

  return loc
end

-- Apply a tmux target via the shared c-tmux-restore helper (silent).
local function applyTmux(loc)
  if not isTmuxLoc(loc) then
    log("applyTmux skipped: not a tmux loc (" .. tostring(loc) .. ")")
    return
  end

  log("applyTmux: " .. loc)
  hs.execute(TMUX_RESTORE_CMD .. " " .. shellQuote(loc), true)
end

-- True when a back-path snapshot exists on disk (still consumable by restoreFull).
function M.hasSnapshot()
  local f = io.open(FULL_PATH, "r")
  if not f then return false end

  f:close()
  return true
end

-- Cmd+k: return to the pre-jump app (+ tmux if Ghostty). macOS's `activate`
-- handles the Space switch implicitly by surfacing the app's window.
function M.restoreFull()
  local snap = readJSON(FULL_PATH)

  if not snap then
    log("restoreFull: no snapshot")
    notify("Cmd+K · no snapshot", "Nothing to restore")
    return
  end

  -- One-shot: consume the cache up-front so a second press is a no-op until
  -- the next notification re-captures (even if a later step errors).
  os.remove(FULL_PATH)

  log(string.format("restoreFull: app=%s ghostty=%s tmux=%s",
    tostring(snap.app_bundle or snap.app_name),
    tostring(snap.is_ghostty), tostring(snap.tmux)))

  if isFrontmost(snap.app_bundle, snap.app_name) then
    log(string.format("restoreFull: %s already frontmost — skip activate",
      tostring(snap.app_bundle or snap.app_name)))
  else
    local ok = activateApp(snap.app_name, snap.app_bundle)

    log(string.format("restoreFull: activate name=%s bundle=%s ok=%s",
      tostring(snap.app_name), tostring(snap.app_bundle), tostring(ok)))
  end

  if snap.is_ghostty and isTmuxLoc(snap.tmux) then
    applyTmux(snap.tmux)
  end

  local appLabel = snap.app_name or snap.app_bundle or "?"
  local title = "Return to " .. appLabel
  local subtitle

  if snap.is_ghostty and isTmuxLoc(snap.tmux) then
    subtitle = tmuxLocLabel(snap.tmux)
  else
    subtitle = "-"
  end

  notify(title, subtitle)
end

return M
