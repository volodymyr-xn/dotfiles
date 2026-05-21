-- Shared config + mutable state for memory_cleaner submodules. Kept in a
-- standalone module so stats/prune can require it without creating a cycle
-- through init.lua.

local fn = vim.fn

local M = {}

-- ============================================================================
-- Config (mutate via require("my_plugins.memory_cleaner").config.<key>)
-- ============================================================================

M.config = {
  idle_minutes = 250,
  rss_warn_mb = 80,
  notify_debounce_seconds = 600,
  timer_interval_ms = 10 * 60 * 1000,
  rss_cache_seconds = 5,
  -- LSP clients that must never auto-stop even when their last buffer unloads.
  never_stop_lsp = { "eslint", "copilot" },
  -- RSS sparkline ring buffer: 72 samples × 20 minutes = 24h window.
  rss_sample_interval_ms = 20 * 60 * 1000,
  rss_history_max = 72,
  rss_history_path = fn.stdpath("state") .. "/memory_manager/rss_history.json",
  -- Parser memory estimate in KB by filetype (rough order-of-magnitude).
  parser_estimate_kb = {
    ruby = 400, typescript = 400, javascript = 400, tsx = 450, jsx = 450,
    lua = 250, python = 300, go = 300, rust = 350, c = 250, cpp = 300,
    html = 200, css = 150, scss = 150, json = 100, yaml = 100, markdown = 150,
  },
  -- Status icons (nerd font). Override after require() if your font differs.
  icons = {
    buffer = "󰈔", parser = "󰔱", memory = "󰍛",
    visible = "", hidden = "󰈕", unloaded = "󰈉",
    modified = "󰷈", special = "", current_proc = "",
    spark = { "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█" },
  },
}

-- ============================================================================
-- State (process-local; cleared by setup() each load)
-- ============================================================================

-- Per-buffer "last left" monotonic timestamp in seconds (BufLeave timestamp).
M.last_left_at = {}
-- RSS sampler cache (window in config.rss_cache_seconds).
M.rss_cache = { value = nil, at = 0 }
-- Threshold notify debounce: last fire time + breach window flag.
M.notify_state = { last_fire = 0, in_breach = false }
-- Bytes-per-buffer cache for the reclaim estimate column.
M.buf_bytes_cache = {}
-- RSS history ring buffer (oldest first); persisted between sessions.
M.rss_history = {}
-- Last-fire timestamps (epoch seconds) for the recurring timers. Used by the
-- dashboard to render "next prune in X" / "next sample in Y" countdowns.
M.timer_state = {
  last_prune_at = 0,
  last_rss_sample_at = 0,
  setup_at = 0,
}

return M
