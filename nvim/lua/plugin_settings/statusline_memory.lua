-- Statusline Memory setup — single user-visible knobs panel.
--
-- Calls `my_plugins.statusline_memory.setup({...})` with the project's
-- tuned values. Any key omitted here falls back to the default defined in
-- `my_plugins/statusline_memory/init.lua`; pass only the values you want
-- to override.
--
-- Wired in `plugins_require.lua` (must run after Neovim startup so the
-- VimEnter warm-up + repeating timer get installed).

require("my_plugins.statusline_memory").setup({
  -- How often the statusline value is resampled. Each tick shells out to
  -- `ps` once (subject to memory_cleaner's RSS cache). Long interval keeps
  -- overhead trivial; short interval makes the readout match :MemDashboard
  -- more tightly when memory is churning.
  refresh_interval_seconds = 10 * 60,

  -- Two post-VimEnter samples — 2s catches eagerly-loaded plugins, 10s
  -- catches the slower lazy-loaders. Add more entries to keep correcting
  -- during a long startup; both delays must sit outside memory_cleaner's
  -- `rss_reading_cache_seconds` so the second one re-reads `ps` instead of
  -- hitting the cache.
  warmup_delays_ms = { 2000, 10000 },
})
