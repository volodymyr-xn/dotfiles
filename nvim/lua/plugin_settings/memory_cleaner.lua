-- Memory cleaner timings — single user-visible knobs panel.
--
-- All schedule-driven values for `my_plugins.memory_cleaner` live here so they
-- can be tuned without spelunking into the engine module. Defaults in
-- `my_plugins/memory_cleaner/shared.lua` remain as a safety net; values below
-- override them via the public `.config` interface.
--
-- This file MUST be required before `memory_cleaner.setup()` is called (wired
-- in `plugins_require.lua`), so the first prune/sample tick uses these values.

local config = require("my_plugins.memory_cleaner").config

-- How long a buffer must sit unfocused (no BufLeave activity) before the
-- periodic sweep is allowed to unload it. Higher = fewer unloads, more RAM
-- held; lower = aggressive reclaim, more re-reads when revisiting files.
config.unload_buffer_after_idle_minutes = 250

-- Minimum gap between two RSS-over-threshold warning notifications, so a
-- sustained breach doesn't spam the notify stack on every timer tick.
config.rss_warn_notify_debounce_seconds = 600

-- Period of the main worker tick. One tick runs the idle-buffer prune AND
-- the RSS-threshold notify check. Lower = quicker reclaim and faster
-- warnings, but more wake-ups; the default 10min keeps overhead negligible.
config.prune_tick_interval_seconds = 10 * 60

-- TTL for the cached RSS reading. Stats/statusline callers within this
-- window reuse the last value instead of shelling out to `ps`. Short enough
-- to stay fresh, long enough to absorb bursty lualine redraws.
config.rss_reading_cache_seconds = 5

-- Period of the RSS sparkline sampler. With `rss_history_max_samples = 72`
-- (kept in shared.lua), 20 minutes × 72 samples spans a 24h dashboard
-- window. Change alongside `rss_history_max_samples` for a different span.
config.rss_history_sample_interval_seconds = 20 * 60
