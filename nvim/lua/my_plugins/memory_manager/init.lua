-- Memory Manager — public entry point.
--
-- Wires autocmds (BufLeave timestamping, fugitive blame auto-wipe,
-- BufUnload/BufWipeout state cleanup), user commands (:MemPrune, :MemDashboard),
-- the 60-second prune + RSS-notify timer, and the 20-minute sparkline sampler.
--
-- Public surface:
--   require("my_plugins.memory_manager").setup()
--   .rss_mb() / .stats() / .stats_string()  -- statusline accessors
--   .prune({ force_minutes = N })           -- programmatic prune

local uv = vim.uv or vim.loop
local api = vim.api
local fn = vim.fn

local shared = require("my_plugins.memory_manager.shared")
local stats = require("my_plugins.memory_manager.stats")
local prune = require("my_plugins.memory_manager.prune")
local rpc = require("my_plugins.memory_manager.rpc")
local dashboard = require("my_plugins.memory_manager.dashboard")

local M = {}

-- Re-export public surface (so external code keeps the flat namespace).
M.config = shared.config
M.dashboard_state = shared.dashboard_state
M.rss_mb = stats.rss_mb
M.rss_mb_for = stats.rss_mb_for
M.stats = stats.stats
M.stats_string = stats.stats_string
M.prune = prune.prune
M.discover_processes = rpc.discover_processes
M.stats_remote = rpc.stats_remote
M.remote_exec = rpc.remote_exec
M.remote_buf_delete = rpc.remote_buf_delete
M.dashboard = dashboard.open

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

  if mb > shared.config.rss_warn_mb then
    local now = os.time()
    local since = now - shared.notify_state.last_fire

    if (not shared.notify_state.in_breach) or since >= shared.config.notify_debounce_seconds then
      shared.notify_state.in_breach = true
      shared.notify_state.last_fire = now
      vim.notify(string.format("[mem] RSS %dM > %dM (%s)",
        mb, shared.config.rss_warn_mb, stats.stats_string()), vim.log.levels.WARN)
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

  local group = api.nvim_create_augroup("MemoryManager", { clear = true })

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

  -- :MemDashboard — open the cross-process dashboard float.
  api.nvim_create_user_command("MemDashboard", function() dashboard.open() end, {})

  -- 60s timer drives prune + RSS-threshold notify in one tick.
  local prune_timer = uv.new_timer()
  prune_timer:start(shared.config.timer_interval_ms, shared.config.timer_interval_ms,
    vim.schedule_wrap(on_timer_tick))

  -- 20-min sampler feeds the RSS sparkline ring buffer; stamp tick time so
  -- the dashboard can render an accurate "next sample in" countdown.
  local function on_rss_tick()
    shared.timer_state.last_rss_sample_at = os.time()
    stats.sample_history()
  end

  stats.load_history()
  on_rss_tick() -- seed with a sample at startup
  local rss_timer = uv.new_timer()
  rss_timer:start(shared.config.rss_sample_interval_ms, shared.config.rss_sample_interval_ms,
    vim.schedule_wrap(on_rss_tick))
end

return M
