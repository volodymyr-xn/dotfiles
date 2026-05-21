-- Statusline Memory — lualine component that prints nvim's RSS footprint.
--
-- Owns its own refresh timer + VimEnter warm-up samples so the displayed
-- value never depends on lualine's per-frame redraw cadence. Lualine reads
-- the cached string via `get_string()`; the underlying RSS read is
-- delegated to `my_plugins.memory_cleaner.stats.rss_mb()`.
--
-- Public surface:
--   require("my_plugins.statusline_memory").setup({ ... })  -- starts timers
--   require("my_plugins.statusline_memory").get_string()    -- lualine accessor
--   require("my_plugins.statusline_memory").refresh()       -- force resample

local uv = vim.uv or vim.loop
local api = vim.api

local M = {}

-- ============================================================================
-- Config defaults — override by passing an opts table to setup().
-- The project's tuned values live in
-- `plugin_settings/statusline_memory.lua` — change them there, not here.
-- ============================================================================

M.config = {
  -- Period of the lualine readout refresh. Each tick shells out to `ps` once
  -- (subject to memory_cleaner's own RSS cache window).
  refresh_interval_seconds = 10 * 60,
  -- Deferred warm-up samples relative to VimEnter. Sampling during plugin
  -- load returns an artificially low RSS; lazy-loaded plugins finish
  -- initialising over the first several seconds. Each entry is forced past
  -- memory_cleaner's RSS cache window so the second sample reads fresh.
  warmup_delays_ms = { 2000, 10000 },
  -- Nerd-font glyph rendered before the value (nf-md-chip = 󰘚).
  icon = "󰘚",
  -- Placeholder shown until the first sample lands.
  initial_placeholder = "…",
  -- Placeholder shown when the RSS read fails (rare; usually a broken `ps`).
  unknown_placeholder = "?M",
}

-- ============================================================================
-- State
-- ============================================================================

-- Cached string read by lualine on every redraw; no shell-out per frame.
local cached_str = nil

-- Compose "<icon> <value>" with the configured glyph + spacing.
local function format_str(value)
  return M.config.icon .. " " .. value
end

-- Resample RSS via memory_cleaner.stats and update the cached string.
function M.refresh()
  local ok, stats = pcall(require, "my_plugins.memory_cleaner.stats")

  if not ok then
    cached_str = format_str(M.config.unknown_placeholder)
    return
  end

  local mb = stats.rss_mb()
  cached_str = format_str(mb and (mb .. "M") or M.config.unknown_placeholder)
end

-- Lualine accessor; returns the cached string (never shells out).
function M.get_string()
  return cached_str or format_str(M.config.initial_placeholder)
end

-- One-time wiring. `opts` is a partial config table merged on top of the
-- defaults above — callers pass any subset of the keys documented there.
function M.setup(opts)
  if opts ~= nil then
    M.config = vim.tbl_deep_extend("force", M.config, opts)
  end

  cached_str = format_str(M.config.initial_placeholder)

  -- Warm-up samples after VimEnter so the first reading reflects the
  -- post-plugin-load footprint instead of the bootstrap one.
  api.nvim_create_autocmd("VimEnter", {
    once = true,
    callback = function()
      for _, delay_ms in ipairs(M.config.warmup_delays_ms) do
        vim.defer_fn(M.refresh, delay_ms)
      end
    end,
  })

  -- Periodic resample; lualine reads the cached string between ticks.
  local interval_ms = M.config.refresh_interval_seconds * 1000
  local timer = uv.new_timer()
  timer:start(interval_ms, interval_ms, vim.schedule_wrap(M.refresh))
end

return M
