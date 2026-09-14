-- Stall Watchdog — detects when nvim's main event queue stops draining.
--
-- A wedged main loop is invisible from inside nvim: `vim.notify`, `vim.cmd`
-- and every `vim.schedule` callback are precisely what stops running. Only a
-- `vim.uv` timer keeps firing, because libuv timer callbacks run in a fast
-- event context. So this module lives there — it queues a single probe
-- through `vim.schedule` and reports a stall when that probe fails to come
-- back within the threshold.
--
-- Why it matters: while the queue is stalled, every pending `vim.schedule`
-- callback stays rooted in the Lua registry (`nlua_ref_global`), holding
-- whatever it captured. Any plugin polling on a short uv timer then grows
-- the queue without bound — the observed failure mode was 13.3 GB across
-- ~17.8M queued events over eight days.
--
-- Detection only: it never touches editor state, so it cannot cancel a
-- legitimate blocking prompt (`input()`, `getchar()`, `:confirm`), which is
-- itself a normal main-loop stall.
--
-- Public surface:
--   require("my_plugins.stall_watchdog").setup({ ... })  -- starts the timer
--   require("my_plugins.stall_watchdog").status()        -- state snapshot

local uv = vim.uv or vim.loop
local api = vim.api
local utils = require("my_plugins.my_utils")

local M = {}

-- ============================================================================
-- Config defaults — override by passing an opts table to setup().
-- The project's tuned values live in
-- `plugin_settings/stall_watchdog.lua` — change them there, not here.
-- ============================================================================

M.config = {
  -- How often the uv heartbeat fires. Also the probe cadence while healthy,
  -- since at most one probe is ever in flight. One queued event every few
  -- seconds is free; the mechanism that leaked 13 GB was identical except
  -- that it re-queued unconditionally.
  heartbeat_interval_ms = 5 * 1000,
  -- How long a probe may stay unanswered before the stall is reported.
  -- Generous on purpose: a prompt left open is a legitimate stall, and the
  -- queue only grows a few MB even after an hour, so false alarms cost more
  -- than late detection.
  stall_threshold_ms = 5 * 60 * 1000,
  -- Re-notify cadence while a single stall persists, so one missed banner
  -- does not mean the instance is forgotten. 0 notifies only once.
  renotify_interval_ms = 60 * 60 * 1000,
  -- Quiet period after VimEnter before the first probe. Startup legitimately
  -- blocks the loop (lazy loaders, LSP attach), so probing during it is noise.
  startup_grace_ms = 30 * 1000,
  -- Title of the OS notification.
  notification_title = "Neovim main loop stalled",
  -- Append-only log of stall/recovery events, which survives the restart a
  -- wedged instance needs. `nil` resolves to
  -- `stdpath("log")/stall_watchdog.log`; `false` disables logging.
  log_path = nil,
}

-- ============================================================================
-- State
-- ============================================================================

-- Live heartbeat handle, kept so a re-setup() stops the previous timer
-- instead of stacking a second one.
local heartbeat_timer = nil

-- `uv.now()` when the in-flight probe was queued; nil when none is pending.
-- Doubles as the "one probe at a time" lock that keeps this module from
-- becoming the very leak it watches for.
local probe_queued_at_ms = nil

-- `uv.now()` of the last probe that made it back through the main loop.
local last_drained_at_ms = 0

-- `uv.now()` of the last notification for the current stall; nil while
-- healthy, which is also what marks a stall as unreported.
local stall_notified_at_ms = nil

-- Captured on the main loop by each successful probe, so a stall report can
-- name the instance's working directory without calling a non-fast API.
local last_known_cwd = "?"

-- Resolved once in setup(); nil means logging is off.
local log_file_path = nil

-- ============================================================================
-- Internals
-- ============================================================================

-- Escape a value for embedding in an AppleScript double-quoted string.
-- Backslashes first, or the added quote escapes get re-escaped in turn.
local function escape_for_applescript(text)
  return (text:gsub("\\", "\\\\"):gsub('"', '\\"'))
end

-- Argv for an OS-level notification, as (command, args) for this platform.
-- The repo targets macOS and Linux only, so those are the two cases.
local function notification_command(title, message)
  if uv.os_uname().sysname == "Darwin" then
    local applescript = string.format(
      'display notification "%s" with title "%s"',
      escape_for_applescript(message),
      escape_for_applescript(title)
    )

    return "osascript", { "-e", applescript }
  end

  return "notify-send", { title, message }
end

-- Append one line to the stall log. Uses the synchronous `uv.fs_*` calls
-- because `vim.fn.writefile` and friends are unavailable in a fast context.
local function log_line(message)
  if not log_file_path then
    return
  end

  -- pcall because luv's synchronous fs calls raise on failure, and a broken
  -- log path must never propagate into the heartbeat callback.
  pcall(function()
    local file_descriptor = uv.fs_open(log_file_path, "a", 420)

    if not file_descriptor then
      return
    end

    uv.fs_write(file_descriptor, string.format("%s  %s\n", os.date("%Y-%m-%d %H:%M:%S"), message))
    uv.fs_close(file_descriptor)
  end)
end

-- Spawn the platform notifier detached, fire-and-forget. Safe in a fast
-- context because `uv.spawn` never enters the editor — unlike `vim.system`,
-- whose completion path goes through `vim.schedule`, the queue we cannot
-- trust here. A missing notifier binary makes `uv.spawn` return nil rather
-- than raise, so a stall still reaches the log.
local function notify_externally(title, message)
  local command, command_args = notification_command(title, message)
  local process_handle

  process_handle = uv.spawn(command, {
    args = command_args,
    detached = true,
    stdio = { nil, nil, nil },
  }, function()
    -- Release the handle so a long session does not accumulate one dead
    -- child handle per notification.
    if process_handle then
      process_handle:close()
    end
  end)
end

-- Render a stall duration without fmt_uptime's "ago" suffix, which reads
-- wrong for an elapsed span ("recovered after 5 minutes", not "5 minutes ago").
local function format_elapsed(milliseconds)
  local seconds = math.floor(milliseconds / 1000)
  -- Bound to a local so gsub's replacement count is not returned alongside
  -- the string, which would leak an extra argument into string.format.
  local elapsed_text = (utils.fmt_uptime(seconds) or "?"):gsub(" ago$", "")

  return elapsed_text
end

-- Runs on the main event loop. Reaching it is the proof that the queue
-- drained, so it clears the in-flight lock and reports any recovery.
local function complete_probe()
  local drained_at_ms = uv.now()
  local stalled_for_ms = drained_at_ms - (probe_queued_at_ms or drained_at_ms)
  local recovered_from_stall = stall_notified_at_ms ~= nil

  -- Release the in-flight lock before any reporting. A throw in the notifier
  -- or the log write would otherwise latch the watchdog into a permanent
  -- false stall, since nothing else ever clears this lock.
  probe_queued_at_ms = nil
  stall_notified_at_ms = nil
  last_drained_at_ms = drained_at_ms
  last_known_cwd = uv.cwd() or "?"

  if recovered_from_stall then
    local recovery_message = string.format(
      "PID %d recovered after %s",
      uv.os_getpid(),
      format_elapsed(stalled_for_ms)
    )

    notify_externally("Neovim main loop recovered", recovery_message)
    log_line(recovery_message)
  end
end

-- Report the current stall, honouring the re-notify cadence so a persistent
-- stall produces a periodic reminder rather than one banner or a flood.
local function report_stall(now_ms)
  local renotify_interval_ms = M.config.renotify_interval_ms or 0

  if stall_notified_at_ms then
    if renotify_interval_ms <= 0 or now_ms - stall_notified_at_ms < renotify_interval_ms then
      return
    end
  end

  stall_notified_at_ms = now_ms

  local message = string.format(
    "PID %d — no events processed for %s. Memory grows until restart. %s",
    uv.os_getpid(),
    format_elapsed(now_ms - probe_queued_at_ms),
    last_known_cwd
  )

  notify_externally(M.config.notification_title, message)
  log_line(message)
end

-- Runs in a uv fast event context, which is why it keeps firing while the
-- main loop is wedged. Queues a probe when none is pending, otherwise checks
-- how long the pending one has gone unanswered.
local function check_heartbeat()
  local now_ms = uv.now()

  if not probe_queued_at_ms then
    probe_queued_at_ms = now_ms
    vim.schedule(complete_probe)
    return
  end

  if now_ms - probe_queued_at_ms >= M.config.stall_threshold_ms then
    report_stall(now_ms)
  end
end

-- Arm the heartbeat. Split out so it can run either from VimEnter or
-- immediately, when setup() is called after startup has already finished.
local function start_heartbeat()
  last_drained_at_ms = uv.now()
  heartbeat_timer = uv.new_timer()
  heartbeat_timer:start(
    M.config.startup_grace_ms,
    M.config.heartbeat_interval_ms,
    check_heartbeat
  )
end

-- ============================================================================
-- Public surface
-- ============================================================================

-- Snapshot of the watchdog's view of the loop, for `:StallStatus` and for
-- poking at from `:lua`.
function M.status()
  local now_ms = uv.now()

  return {
    running = heartbeat_timer ~= nil,
    probe_pending = probe_queued_at_ms ~= nil,
    pending_for_seconds = probe_queued_at_ms and math.floor((now_ms - probe_queued_at_ms) / 1000) or 0,
    last_drained_seconds_ago = math.floor((now_ms - last_drained_at_ms) / 1000),
    stall_reported = stall_notified_at_ms ~= nil,
    log_path = log_file_path or "disabled",
  }
end

-- One-time wiring. Idempotent: a repeat call (e.g. `<Leader>vr` re-sourcing
-- $MYVIMRC) re-merges config and restarts the single timer rather than
-- stacking another one. `opts` is a partial config table merged on top of
-- the defaults above.
function M.setup(opts)
  if opts ~= nil then
    M.config = vim.tbl_deep_extend("force", M.config, opts)
  end

  if M.config.log_path == nil then
    log_file_path = vim.fn.stdpath("log") .. "/stall_watchdog.log"
  elseif M.config.log_path == false then
    log_file_path = nil
  else
    log_file_path = M.config.log_path
  end

  if heartbeat_timer then
    heartbeat_timer:stop()
    heartbeat_timer:close()
    heartbeat_timer = nil
  end

  -- :StallStatus — echo the watchdog's current view of the event loop.
  api.nvim_create_user_command("StallStatus", function()
    vim.notify(vim.inspect(M.status()), vim.log.levels.INFO)
  end, { desc = "Show main-loop stall watchdog status" })

  last_known_cwd = uv.cwd() or "?"

  -- Startup legitimately blocks the loop, so the heartbeat waits for
  -- VimEnter. On a re-setup() after startup that event will never fire
  -- again, so arm the timer directly instead of leaving the watchdog dead.
  if vim.v.vim_did_enter == 1 then
    start_heartbeat()
    return
  end

  -- Cleared augroup so a second pre-VimEnter setup() cannot queue two arms.
  api.nvim_create_autocmd("VimEnter", {
    group = api.nvim_create_augroup("stall_watchdog", { clear = true }),
    once = true,
    callback = start_heartbeat,
  })
end

return M
