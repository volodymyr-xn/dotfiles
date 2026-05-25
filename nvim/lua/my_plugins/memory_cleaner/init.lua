-- Memory Cleaner — eagerly-loaded cleanup engine.
--
-- Owns all schedule-based memory reclaim: BufLeave timestamping, fugitive
-- blame auto-wipe, BufUnload/BufWipeout state cleanup, the 60-second prune +
-- RSS-notify timer, and the 20-minute sparkline sampler. Also registers the
-- :MemClear family of manual escape hatches (and the per-subsystem
-- :MemClearTreesitter / :MemClearFugitive / :MemClearLsp variants).
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
local subsystems = require("my_plugins.memory_cleaner.subsystems")
local utils = require("my_plugins.my_utils")

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
M.clear_treesitter = subsystems.clear_treesitter
M.clear_fugitive = subsystems.clear_fugitive
M.clear_lsp = subsystems.clear_lsp
M.clear_all = subsystems.clear_all
M.gc = subsystems.gc

-- Periodic tick: run prune; announce reclaims, and warn once per RSS
-- threshold *crossing* (not once per tick while sustained). The legacy code
-- re-fired every tick and relied on `nvim_echo(history=false)` overwriting
-- the cmdline in place — that assumption broke under nvim 0.12's ui2
-- cmdline/messages, which stacks ephemeral messages until the height cap
-- and then shows a `[+N](total)` overflow indicator. Current RSS is always
-- visible on the statusline via memory_monitor, so a periodic reminder is
-- pure noise once the user has been told the threshold was crossed.
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

  local cfg = shared.config
  local nstate = shared.notify_state
  local threshold = cfg.rss_warn_threshold_mb

  if mb <= threshold then
    nstate.in_breach = false
    return
  end

  if nstate.in_breach then
    return
  end

  -- Anti-flap: if RSS oscillates around the threshold, don't re-fire until
  -- `rss_warn_notify_debounce_seconds` has elapsed since the last warning.
  local now = os.time()
  nstate.in_breach = true

  if (now - nstate.last_fire) < cfg.rss_warn_notify_debounce_seconds then
    return
  end

  nstate.last_fire = now
  api.nvim_echo({{
    string.format("[mem] RSS %s > %s (%s)",
      utils.fmt_mb(mb), utils.fmt_mb(threshold), stats.stats_string()),
    "WarningMsg",
  }}, true, {})
end

-- One-time wiring. Idempotent: the augroup is recreated with `clear = true`,
-- user commands re-register with `force = true`, and the timer block is
-- guarded by `M._setup_done` — without that guard, a second `setup()` call
-- (e.g. via `<Leader>vr` :source $MYVIMRC) starts a second prune timer and
-- a second RSS sampler with no handle to stop the orphaned originals.
-- `opts` is a partial config table merged on top of the defaults from
-- shared.lua — callers pass any subset of the keys documented there.
function M.setup(opts)
  if opts ~= nil then
    shared.config = vim.tbl_deep_extend("force", shared.config, opts)
    M.config = shared.config
  end

  if M._setup_done then
    return
  end

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
        local ok = pcall(api.nvim_buf_delete, args.buf, { force = true })

        if ok then
          vim.notify("[mem] wiped fugitive blame buffer", vim.log.levels.INFO)
        end
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

  -- :MemClear [minutes] — manual escape hatch; 0 == ignore idle time entirely.
  -- Runs the idle-buffer prune + orphan-LSP stop, then two GC passes so the
  -- Lua heap (which can sit at ~70 MB after a long session) collapses too.
  api.nvim_create_user_command("MemClear", function(opts)
    local mins = tonumber(opts.args) or 0
    local result = prune.prune({ force_minutes = mins })
    subsystems.gc()
    vim.notify(prune.format_result(result) .. " · gc", vim.log.levels.INFO)
  end, { nargs = "?" })

  -- :MemClearAll — aggressive sweep: every treesitter parser, every fugitive
  -- buffer, every LSP client (attached or not), plus GC. Use when RSS is
  -- climbing and you want to reset the editor's internal state without
  -- restarting nvim.
  api.nvim_create_user_command("MemClearAll", function()
    local r = subsystems.clear_all()
    vim.notify(string.format("[mem] cleared → %d parsers, %d fugitive, %d LSP · gc",
      r.treesitter, r.fugitive, r.lsp), vim.log.levels.INFO)
  end, {})

  -- :MemClearTreesitter — stop every active treesitter parser/highlighter.
  api.nvim_create_user_command("MemClearTreesitter", function()
    local n = subsystems.clear_treesitter()
    subsystems.gc()
    vim.notify(string.format("[mem] cleared → %d parsers · gc", n), vim.log.levels.INFO)
  end, {})

  -- :MemClearFugitive — wipe every fugitive blame/diff/URI buffer.
  api.nvim_create_user_command("MemClearFugitive", function()
    local n = subsystems.clear_fugitive()
    subsystems.gc()
    vim.notify(string.format("[mem] cleared → %d fugitive · gc", n), vim.log.levels.INFO)
  end, {})

  -- :MemClearLsp — stop every LSP client unconditionally.
  api.nvim_create_user_command("MemClearLsp", function()
    local n = subsystems.clear_lsp()
    subsystems.gc()
    vim.notify(string.format("[mem] cleared → %d LSP · gc", n), vim.log.levels.INFO)
  end, {})

  -- :MemStats — print buffers / parsers / RSS in one line.
  api.nvim_create_user_command("MemStats", function()
    vim.notify("[mem] " .. stats.stats_string(), vim.log.levels.INFO)
  end, {})

  -- :MemRSS — print current RSS, bypassing the cleaner cache for a fresh sample.
  api.nvim_create_user_command("MemRSS", function()
    shared.rss_cache.value = nil
    local mb = stats.rss_mb()
    vim.notify("[mem] RSS " .. (utils.fmt_mb(mb) or "?"), vim.log.levels.INFO)
  end, {})

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

  M._setup_done = true
end

return M
