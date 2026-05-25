-- Memory Monitor — lualine component that prints nvim's RSS footprint.
--
-- Owns its own refresh timer + VimEnter warm-up samples so the displayed
-- value never depends on lualine's per-frame redraw cadence. Lualine reads
-- the cached string via `get_string()`; the underlying RSS read is
-- delegated to `my_plugins.memory_cleaner.stats.rss_mb()`.
--
-- Public surface:
--   require("my_plugins.memory_monitor").setup({ ... })  -- starts timers
--   require("my_plugins.memory_monitor").get_string()    -- lualine accessor
--   require("my_plugins.memory_monitor").refresh()       -- force resample

local uv = vim.uv or vim.loop
local api = vim.api
local utils = require("my_plugins.my_utils")

local M = {}

-- ============================================================================
-- Config defaults — override by passing an opts table to setup().
-- The project's tuned values live in
-- `plugin_settings/memory_monitor.lua` — change them there, not here.
-- ============================================================================

-- Every key below is overridable from `setup({...})`. The values here are
-- safe minimal fallbacks so the module is usable without a settings file;
-- the project's tuned values live in `plugin_settings/memory_monitor.lua`.
M.config = {
  -- Period of the regular lualine readout refresh; only kicks in after the
  -- last warm-up sample. Each tick shells out to `ps` once (subject to
  -- memory_cleaner's own RSS cache window). 0 disables the periodic timer
  -- (warm-up samples still fire).
  refresh_interval_seconds = 10 * 60,
  -- One-shot post-VimEnter warm-up samples. Plugins keep allocating during
  -- the first few minutes (lazy loaders, LSP attach, treesitter parsers),
  -- so resampling on a curve matters. The longest entry also anchors when
  -- the periodic timer starts. Empty list = no warm-ups.
  warmup_delays_ms = { 3 * 1000, 15 * 1000 },
  -- Nerd-font glyph rendered before the value (nf-md-chip = 󰘚). Replace
  -- with any string (even empty) to swap or drop the icon.
  icon = "󰘚",
  -- Single space between icon and value; set to "" to butt them together
  -- or to a longer separator for extra breathing room.
  icon_separator = " ",
  -- Placeholder shown until the first sample lands.
  initial_placeholder = "…",
  -- Placeholder shown when the RSS read fails (rare; usually a broken `ps`
  -- or memory_cleaner not yet loaded).
  unknown_placeholder = "?",
}

-- ============================================================================
-- State
-- ============================================================================

-- Cached string read by lualine on every redraw; no shell-out per frame.
local cached_str = nil

-- Compose "<icon><sep><value>"; icon is dropped entirely if empty so a
-- bare "234M" is possible by setting `icon = ""`.
local function format_str(value)
  local icon = M.config.icon or ""

  if icon == "" then
    return value
  end

  return icon .. (M.config.icon_separator or "") .. value
end

-- Resample RSS via memory_cleaner.stats and update the cached string.
function M.refresh()
  local ok, stats = pcall(require, "my_plugins.memory_cleaner.stats")

  if not ok then
    cached_str = format_str(M.config.unknown_placeholder)
    return
  end

  local mb = stats.rss_mb()
  cached_str = format_str(utils.fmt_mb(mb) or M.config.unknown_placeholder)
end

-- Lualine accessor; returns the cached string (never shells out).
function M.get_string()
  return cached_str or format_str(M.config.initial_placeholder)
end

-- One-time wiring. Idempotent: `M._setup_done` guards the VimEnter autocmd
-- and timer wiring against double-`setup()` (e.g. via `<Leader>vr` :source
-- $MYVIMRC, which would otherwise stack a second periodic timer with no
-- handle to stop the first). `opts` is a partial config table merged on
-- top of the defaults above — callers pass any subset of the keys documented
-- there.
function M.setup(opts)
  if opts ~= nil then
    M.config = vim.tbl_deep_extend("force", M.config, opts)
  end

  if M._setup_done then
    return
  end

  cached_str = format_str(M.config.initial_placeholder)

  -- :MemStatusRefresh — force a fresh RSS sample and redraw the statusline.
  api.nvim_create_user_command("MemStatusRefresh", function()
    -- Bypass memory_cleaner's RSS cache so the readout reflects this instant.
    local ok, cleaner_shared = pcall(require, "my_plugins.memory_cleaner.shared")

    if ok then
      cleaner_shared.rss_cache.value = nil
    end

    M.refresh()
    vim.cmd("redrawstatus!")
  end, {})

  -- :MemStatus — echo the current cached statusline reading.
  api.nvim_create_user_command("MemStatus", function()
    vim.notify(M.get_string(), vim.log.levels.INFO)
  end, {})

  -- Find the latest warm-up delay so the periodic timer starts exactly one
  -- `refresh_interval_seconds` after it (avoids a near-duplicate fire when
  -- the last warm-up and the first periodic tick land close together).
  local last_warmup_ms = 0

  for _, delay_ms in ipairs(M.config.warmup_delays_ms) do
    if delay_ms > last_warmup_ms then
      last_warmup_ms = delay_ms
    end
  end

  local interval_ms = (M.config.refresh_interval_seconds or 0) * 1000

  -- Warm-up samples + periodic timer are both anchored to VimEnter so
  -- nothing fires while plugins are still loading.
  api.nvim_create_autocmd("VimEnter", {
    once = true,
    callback = function()
      for _, delay_ms in ipairs(M.config.warmup_delays_ms or {}) do
        vim.defer_fn(M.refresh, delay_ms)
      end

      -- Start the regular timer right after the last warm-up sample. Its
      -- first tick fires `interval_ms` later, so the cadence reads as:
      -- warm-ups → +interval → tick → +interval → tick → ...
      -- Disabled entirely when `refresh_interval_seconds` is 0.
      if interval_ms > 0 then
        vim.defer_fn(function()
          local timer = uv.new_timer()
          timer:start(interval_ms, interval_ms, vim.schedule_wrap(M.refresh))
        end, last_warmup_ms)
      end
    end,
  })

  M._setup_done = true
end

return M
