local M = {}

-- Snapshots live next to the agent-notify watcher log so everything for this
-- feature shares one cache dir; they persist across reboots.
local CACHE_DIR = os.getenv("HOME") .. "/.cache/agent_notify"
local FULL_PATH = CACHE_DIR .. "/restore_full.json"
local TMUX_PATH = CACHE_DIR .. "/restore_tmux.json"
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
local function notify(text, detail)
  local attrs = {
    title = "Return",
    informativeText = text,
    withdrawAfter = 4,
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

-- Consume a snapshot after a successful restore (re-press becomes a no-op).
local function clearFile(path)
  os.remove(path)
end

-- Capture the user's pre-jump location before agent_notify forwards focus.
-- `tmuxLoc`   = the user's current tmux pane id (%N), "" / nil if not in tmux.
-- `agentPane` = the agent's pane id (the forward jump's target).
--
-- A tmux loc is a real return target only if it differs from the agent's
-- pane (else "go back" == "stay here"). If the user is *in Ghostty sitting
-- on the agent's pane*, the whole full snapshot is a pure self-reference
-- (Ghostty + its Space + the agent pane) — skip writing so a prior,
-- still-unused return point survives. For any other app (e.g. Chrome) the
-- Space+app IS a real return point, so always write the full snapshot.
function M.capture(tmuxLoc, agentPane)
  local space = hs.spaces.focusedSpace()
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
  -- specific window — so no window id is captured.
  local full = {
    space_id = space,
    app_name = app and app:name() or nil,
    app_bundle = bundle,
    is_ghostty = isGhostty,
    -- tmux loc only when captured in Ghostty AND it is a real (non-self) loc
    tmux = (isGhostty and goodTmux) and tmuxLoc or nil,
  }
  writeJSON(FULL_PATH, full)

  -- Cmd+i snapshot: app-independent, but only a real (non-self) tmux loc;
  -- otherwise leave the prior one-shot cache untouched.
  if goodTmux then
    writeJSON(TMUX_PATH, { tmux = tmuxLoc })
  end

  log(string.format(
    "capture: space=%s app=%s ghostty=%s tmuxLoc=%q agent=%s stored_tmux=%s tmux_cache=%s",
    tostring(space), tostring(bundle), tostring(isGhostty),
    tostring(tmuxLoc), tostring(agentPane),
    tostring(full.tmux), tostring(goodTmux and tmuxLoc or "unchanged")))
end

-- True when `spaceID` is still a live Space on some screen.
local function spaceExists(spaceID)
  if not spaceID then return false end

  for _, ids in pairs(hs.spaces.allSpaces() or {}) do
    for _, id in ipairs(ids) do
      if id == spaceID then return true end
    end
  end

  return false
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

-- Cmd+k: return to the exact pre-jump Space + window (+ tmux if Ghostty).
function M.restoreFull()
  local snap = readJSON(FULL_PATH)
  if not snap then
    log("restoreFull: no snapshot")
    notify("Cmd+K · no snapshot", "Nothing to restore")
    return
  end

  -- One-shot: consume both caches up-front so a second press is a no-op
  -- until the next notification re-captures (even if a later step errors).
  -- Also clears the Cmd+I cache so both keys stay in sync.
  clearFile(FULL_PATH)
  clearFile(TMUX_PATH)

  log(string.format("restoreFull: space=%s app=%s ghostty=%s tmux=%s",
    tostring(snap.space_id), tostring(snap.app_bundle or snap.app_name),
    tostring(snap.is_ghostty), tostring(snap.tmux)))

  if snap.space_id and spaceExists(snap.space_id) then
    if hs.spaces.focusedSpace() == snap.space_id then
      -- Already on the target Space. gotoSpace drives Mission Control via
      -- the Dock and always produces an unsuppressable visual transition
      -- (per hs.spaces docs), which reads as a re-focus — so skip it.
      log("restoreFull: already on space " .. tostring(snap.space_id) ..
        " — skip gotoSpace")
    else
      hs.spaces.gotoSpace(snap.space_id)
      log("restoreFull: gotoSpace " .. tostring(snap.space_id) ..
        " (now " .. tostring(hs.spaces.focusedSpace()) .. ")")
    end
  else
    log("restoreFull: space skipped (id=" .. tostring(snap.space_id) ..
      " exists=" .. tostring(spaceExists(snap.space_id)) .. ")")
  end

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

  local title
  if snap.is_ghostty and isTmuxLoc(snap.tmux) then
    title = 'Back to Ghostty tmux "' .. tmuxLocLabel(snap.tmux) .. '"'
  else
    title = "Back to " .. tostring(snap.app_name or snap.app_bundle or "?")
  end

  notify(title, "space " .. tostring(snap.space_id))
end

-- Cmd+i: always land in Ghostty and restore the captured tmux location.
-- Strict one-shot: the cache is consumed on every press (mirrors Cmd+k);
-- a second press is a no-op until the next notification re-captures.
function M.restoreTmux()
  local snap = readJSON(TMUX_PATH)
  local loc = snap and snap.tmux or nil

  -- Only act when a cache exists: no Ghostty activation, no navigation
  -- otherwise (a second press is a no-op until the next notification).
  if not isTmuxLoc(loc) then
    local reason = snap and "snapshot has no tmux loc" or "no snapshot"
    log("restoreTmux: no cache — no-op (" .. reason .. ")")
    notify("Cmd+I · " .. reason, "Nothing to restore")
    return
  end

  -- Consume both caches up-front so the press is one-shot even if a later
  -- step errors. Also clears the Cmd+K cache to keep both keys in sync.
  clearFile(TMUX_PATH)
  clearFile(FULL_PATH)

  local activated = activateApp("Ghostty", GHOSTTY_BUNDLE)
  applyTmux(loc)

  log(string.format("restoreTmux: ghostty_activated=%s loc=%s",
    tostring(activated), tostring(loc)))
  notify('Back to Ghostty tmux "' .. tmuxLocLabel(loc) .. '"')
end

return M
