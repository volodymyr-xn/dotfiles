-- Memory Cleaner — eagerly-loaded cleanup engine.
--
-- Owns all schedule-based memory reclaim: BufLeave timestamping, fugitive
-- blame auto-wipe, BufUnload/BufWipeout state cleanup, the 60-second prune +
-- RSS-notify timer, and the 20-minute sparkline sampler. Also registers the
-- :MemPrune manual escape hatch.
--
-- Public surface:
--   require("my_plugins.memory_cleaner").setup()
--   .rss_mb() / .stats() / .stats_string()  -- statusline accessors
--   .prune({ force_minutes = N })           -- programmatic prune
--   .shared / .config                       -- state + tunables
--
-- The Memory Manager dashboard is a separate, lazy-loaded plugin that consumes
-- this module's public surface.

local uv = vim.uv or vim.loop
local api = vim.api

local shared = require("my_plugins.memory_cleaner.shared")
local stats = require("my_plugins.memory_cleaner.stats")
local prune = require("my_plugins.memory_cleaner.prune")

local M = {}

-- Re-export public surface (so external code keeps the flat namespace).
M.shared = shared
M.config = shared.config
M.rss_mb = stats.rss_mb
M.rss_mb_for = stats.rss_mb_for
M.lstart_for = stats.lstart_for
M.stats = stats.stats
M.stats_string = stats.stats_string
M.render_sparkline = stats.render_sparkline
M.prune = prune.prune
M.is_exempt = prune.is_exempt
M.estimate_buf_kb = prune.estimate_buf_kb
M.format_prune_result = prune.format_result

-- Periodic tick: run prune, surface a notify only when something was actually
-- reclaimed (otherwise the auto-prune would spam every interval).
local function on_timer_tick()
  shared.timer_state.last_prune_at = os.time()
  local result = prune.prune({})

  if result.unloaded > 0 or result.lsp_stopped > 0 then
    vim.notify(prune.format_result(result), vim.log.levels.INFO)
  end

  local mb = stats.rss_mb()

  if not mb then
    return
  end

  if mb > shared.config.rss_warn_threshold_mb then
    local now = os.time()
    local since = now - shared.notify_state.last_fire
    local debounce = shared.config.rss_warn_notify_debounce_seconds

    if (not shared.notify_state.in_breach) or since >= debounce then
      shared.notify_state.in_breach = true
      shared.notify_state.last_fire = now
      vim.notify(string.format("[mem] RSS %dM > %dM (%s)",
        mb, shared.config.rss_warn_threshold_mb, stats.stats_string()), vim.log.levels.WARN)
    end
  else
    shared.notify_state.in_breach = false
  end
end

-- One-time wiring. Idempotent via the augroup `clear = true`.
function M.setup()
  -- Seed BufLeave timestamps for already-open buffers so the first sweep
  -- doesn't immediately unload everything in a freshly-loaded session.
  local now_seconds = uv.hrtime() / 1e9

  for _, buf in ipairs(api.nvim_list_bufs()) do
    shared.last_left_at[buf] = now_seconds
  end

  -- Seed timer-state epoch stamps so the dashboard countdowns are correct
  -- before the first tick fires.
  local now_epoch = os.time()
  shared.timer_state.setup_at = now_epoch
  shared.timer_state.last_prune_at = now_epoch
  shared.timer_state.last_rss_sample_at = now_epoch

  local group = api.nvim_create_augroup("MemoryCleaner", { clear = true })

  -- Track BufLeave timestamps for idle-based pruning.
  api.nvim_create_autocmd("BufLeave", {
    group = group,
    callback = function(args)
      shared.last_left_at[args.buf] = uv.hrtime() / 1e9
      shared.buf_bytes_cache[args.buf] = nil
    end,
  })

  -- Wipe fugitive blame buffers as soon as they leave the screen.
  api.nvim_create_autocmd("BufHidden", {
    group = group,
    callback = function(args)
      if vim.bo[args.buf].filetype == "fugitiveblame" then
        pcall(api.nvim_buf_delete, args.buf, { force = true })
      end
    end,
  })

  -- Forget per-buffer state when a buffer is unloaded externally.
  api.nvim_create_autocmd({ "BufUnload", "BufWipeout" }, {
    group = group,
    callback = function(args)
      shared.last_left_at[args.buf] = nil
      shared.buf_bytes_cache[args.buf] = nil
    end,
  })

  -- :MemPrune [minutes] — manual escape hatch; 0 == ignore idle time entirely.
  api.nvim_create_user_command("MemPrune", function(opts)
    local mins = tonumber(opts.args) or 0
    local result = prune.prune({ force_minutes = mins })
    vim.notify(prune.format_result(result), vim.log.levels.INFO)
  end, { nargs = "?" })

  -- Main worker tick drives prune + RSS-threshold notify in one go.
  local prune_interval_ms = shared.config.prune_tick_interval_seconds * 1000
  local prune_timer = uv.new_timer()
  prune_timer:start(prune_interval_ms, prune_interval_ms,
    vim.schedule_wrap(on_timer_tick))

  -- 20-min sampler feeds the RSS sparkline ring buffer; stamp tick time so
  -- the dashboard can render an accurate "next sample in" countdown.
  local function on_rss_tick()
    shared.timer_state.last_rss_sample_at = os.time()
    stats.sample_history()
  end

  stats.load_history()
  on_rss_tick() -- seed with a sample at startup
  local rss_interval_ms = shared.config.rss_history_sample_interval_seconds * 1000
  local rss_timer = uv.new_timer()
  rss_timer:start(rss_interval_ms, rss_interval_ms, vim.schedule_wrap(on_rss_tick))
end

return M
