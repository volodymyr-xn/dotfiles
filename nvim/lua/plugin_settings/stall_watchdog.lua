-- Stall Watchdog setup — single user-visible knobs panel.
--
-- Calls `my_plugins.stall_watchdog.setup({...})` with the project's tuned
-- values. Any key omitted here falls back to the default defined in
-- `my_plugins/stall_watchdog/init.lua`; pass only what you want to override.
--
-- Wired in `plugins_require.lua`. Detection only — it reports a stalled main
-- event queue through an OS notification and never touches editor state.

require("my_plugins.stall_watchdog").setup({
  -- Probe cadence while healthy. Only ever one probe in flight, so this is
  -- a single queued event every 5s — invisible next to normal editor churn.
  -- Also the detection granularity: a stall is noticed within roughly
  -- `stall_threshold_ms + heartbeat_interval_ms`.
  heartbeat_interval_ms = 5 * 1000,

  -- How long the main loop may go without processing an event before it is
  -- called a stall. Kept high because normal blocking prompts (`input()`,
  -- `getchar()`, `:confirm`, a `q`-pending `:messages` pager) legitimately
  -- stop the queue, and a stall only costs a few MB per hour. Lower it to
  -- ~60s if you would rather hear about brief hangs too.
  stall_threshold_ms = 5 * 60 * 1000,

  -- Reminder cadence while one stall persists. The failure this guards
  -- against ran for eight days, so a single banner is easy to miss.
  -- Set to 0 to notify exactly once per stall.
  renotify_interval_ms = 60 * 60 * 1000,

  -- Quiet period after VimEnter. Lazy loaders and LSP attach block the loop
  -- for real during startup; probing through it only produces false alarms.
  startup_grace_ms = 30 * 1000,

  -- Banner title. The body carries the PID, the stalled duration and the
  -- instance's cwd, which is what you need to find the right window.
  notification_title = "Neovim main loop stalled",

  -- Append-only history of stall/recovery events. Survives the restart a
  -- wedged instance needs, so you can tell afterwards when it went down.
  -- `nil` = `stdpath("log")/stall_watchdog.log`, `false` = no logging.
  log_path = nil,
})
