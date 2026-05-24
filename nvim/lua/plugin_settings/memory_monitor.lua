-- Memory Monitor setup — single user-visible knobs panel.
--
-- Calls `my_plugins.memory_monitor.setup({...})` with the project's tuned
-- values. Any key omitted here falls back to the default defined in
-- `my_plugins/memory_monitor/init.lua`; pass only the values you want to
-- override.
--
-- Wired in `plugins_require.lua` (must run after Neovim startup so the
-- VimEnter warm-up + repeating timer get installed).

require("my_plugins.memory_monitor").setup({
  -- How often the statusline value is resampled once the warm-up phase is
  -- done. Each tick shells out to `ps` once (subject to memory_cleaner's
  -- RSS cache). Long interval keeps overhead trivial; short interval makes
  -- the readout match :MemDashboard more tightly when memory is churning.
  refresh_interval_seconds = 10 * 60,

  -- One-shot post-VimEnter warm-up samples. Plugins keep allocating during
  -- the first few minutes (lazy loaders, LSP attach, treesitter parsers),
  -- so we resample more aggressively early on. After the last entry the
  -- regular `refresh_interval_seconds` timer takes over. Add/remove entries
  -- freely; the longest value also anchors when the periodic timer starts.
  -- Each delay must sit outside memory_cleaner's `rss_reading_cache_seconds`
  -- so consecutive entries actually re-read `ps` instead of hitting the
  -- cache (the defaults below already are).
  warmup_delays_ms = {
    3 * 1000,         -- 3s   — eagerly-loaded plugins finished
    15 * 1000,        -- 15s  — most lazy loaders done
    1 * 60 * 1000,    -- 1m   — first LSPs attached, treesitter parsers warm
    3 * 60 * 1000,    -- 3m   — typical "real working state" footprint
    5 * 60 * 1000,    -- 5m   — steady state baseline
  },

  -- Nerd-font glyph rendered before the value (default: nf-md-chip = 󰘚).
  -- Swap for `󰍛` (nf-md-memory) or any other glyph if your font differs.
  -- Set to "" to drop the icon entirely (separator is then also skipped).
  icon = "󰘚",

  -- Separator between the icon and the numeric value. Default is a single
  -- space; widen for extra breathing room or set "" to butt them together.
  icon_separator = " ",

  -- String shown in place of the RSS value before the first sample lands.
  -- Kept short to avoid layout jitter once the real number appears.
  initial_placeholder = "…",

  -- String shown when the RSS read fails (rare; usually a broken `ps` or
  -- `memory_cleaner` not yet loaded).
  unknown_placeholder = "?",
})
