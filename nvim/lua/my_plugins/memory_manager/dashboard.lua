-- Cross-process Memory Manager dashboard: floating window + render + keymaps.
--
-- Design notes (after the round-1 UI review):
--   * The floating window's title bar already says "Memory Manager"; no
--     duplicated heading line inside the buffer.
--   * Processes render as one bordered table with exactly one row per nvim
--     process — no dividers or sub-rows between them. Buffer detail for an
--     expanded process is listed below the table.
--   * Remote processes start folded; the current process starts expanded.
--   * Sort key is shown once in the top-right of the header — not on every
--     section header.
--   * Status glyphs are single-cell unicode so columns stay aligned with
--     monospaced fonts.

local api = vim.api
local fn = vim.fn
local shared = require("my_plugins.memory_manager.shared")
local cleaner = require("my_plugins.memory_cleaner.shared")
local stats = require("my_plugins.memory_cleaner.stats")
local prune = require("my_plugins.memory_cleaner.prune")
local rpc = require("my_plugins.memory_manager.rpc")
local utils = require("my_plugins.my_utils")

local M = {}

local NS = api.nvim_create_namespace("MemDashboard")
local SECTION_ORDER = { "Visible", "Loaded-Hidden", "Unloaded", "Special" }

-- ============================================================================
-- Highlight groups (link to standard groups so minimal themes still render)
-- ============================================================================

-- Derive a slightly darker shade of NormalFloat's bg for the hint overlay.
-- Returns a "#rrggbb" string, or nil if NormalFloat bg can't be resolved.
local function darker_float_bg()
  local ok, hl = pcall(api.nvim_get_hl, 0, { name = "NormalFloat", link = false })

  if not ok or not hl or not hl.bg then
    return nil
  end

  local r = math.floor(hl.bg / 65536) % 256
  local g = math.floor(hl.bg / 256) % 256
  local b = hl.bg % 256

  local function dim(c)
    return math.max(0, math.floor(c * 0.82))
  end

  return string.format("#%02x%02x%02x", dim(r), dim(g), dim(b))
end

-- Default highlight links so minimal colorschemes still render readably.
local function ensure_highlights()
  local hint_bg = darker_float_bg()

  if hint_bg then
    pcall(api.nvim_set_hl, 0, "MemDashHintBg", { bg = hint_bg, default = true })
  else
    pcall(api.nvim_set_hl, 0, "MemDashHintBg", { link = "Pmenu", default = true })
  end

  local links = {
    MemDashHeaderBorder = "FloatBorder",
    MemDashGood = "DiagnosticOk",
    MemDashTitle = "Title",
    MemDashRSS = "Constant",
    MemDashRSSWarn = "WarningMsg",
    MemDashSpark = "Special",
    MemDashSummary = "Comment",
    MemDashSortKey = "Identifier",
    MemDashCurrent = "Function",
    MemDashRemote = "Normal",
    MemDashPid = "Number",
    MemDashCwd = "Directory",
    MemDashMetric = "Special",
    MemDashMetricWarn = "WarningMsg",
    MemDashMetricDim = "Comment",
    MemDashSection = "Statement",
    MemDashSectionCount = "Comment",
    MemDashBuf = "Normal",
    MemDashBufDim = "Comment",
    MemDashBufModified = "WarningMsg",
    MemDashIdle = "Comment",
    MemDashEst = "Number",
    MemDashSep = "NonText",
    MemDashBoundary = "Special",
    MemDashHint = "Comment",
    MemDashHintKey = "Special",
    MemDashError = "ErrorMsg",
    MemDashUptime = "Comment",
    MemDashUptimeWarn = "WarningMsg",
    MemDashUptimeCritical = "ErrorMsg",
    MemDashTmux = "DiagnosticOk",
  }

  for k, v in pairs(links) do
    pcall(api.nvim_set_hl, 0, k, { link = v, default = true })
  end
end

-- ============================================================================
-- Render helpers
-- ============================================================================

-- Single-cell unicode status glyph for a buffer row.
local function status_glyph(b)
  if b.modified then return "!" end
  if b.buftype ~= "" then return "*" end
  if b.visible then return "●" end
  if b.loaded then return "◐" end
  return "○"
end

-- Visual fold marker for a process row.
local function fold_glyph(pid)
  return shared.dashboard_state.folded[pid] and "▸" or "▾"
end

-- Shorten a long path by collapsing $HOME to ~ and truncating from the front.
local function shorten_path(p, max_len)
  if not p or p == "" then return "?" end
  local home = vim.env.HOME or ""

  if home ~= "" and p:sub(1, #home) == home then
    p = "~" .. p:sub(#home + 1)
  end

  if #p > max_len then
    p = "…" .. p:sub(-max_len + 1)
  end

  return p
end

-- Bucket a buffer into a section name.
local function section_of(b)
  if b.buftype ~= "" then return "Special" end
  if b.visible then return "Visible" end
  if b.loaded then return "Loaded-Hidden" end
  return "Unloaded"
end

-- Sort comparator for the current sort key.
local function sort_buffers(buffers, key)
  table.sort(buffers, function(a, b)
    if key == "size" then
      return (a.est_kb or 0) > (b.est_kb or 0)
    elseif key == "idle" then
      return (a.idle_min or 0) > (b.idle_min or 0)
    else
      return (a.name or "") < (b.name or "")
    end
  end)
end

-- Same sort key applied to the process table: size → RSS, idle → uptime (the
-- process-level analogue of idleness), name → cwd. This nvim stays pinned to
-- the top whatever the key is. Ties break on pid so the order is stable.
local function sort_processes(procs, key)
  table.sort(procs, function(a, b)
    if a.is_current ~= b.is_current then
      return a.is_current
    end

    if key == "idle" then
      local au, bu = a.uptime_seconds or 0, b.uptime_seconds or 0

      if au ~= bu then
        return au > bu
      end
    elseif key == "name" then
      local an, bn = a.cwd or "", b.cwd or ""

      if an ~= bn then
        return an < bn
      end
    else
      local ar, br = a.rss_mb or -1, b.rss_mb or -1

      if ar ~= br then
        return ar > br
      end
    end

    return (a.pid or 0) < (b.pid or 0)
  end)
end

-- Build a string + mark list builder so callers can stream rows by column.
-- Each "segment" pair is { text, highlight_group }.
local function build_line(segments)
  local parts = {}
  local marks = {}
  local col = 0

  for _, seg in ipairs(segments) do
    local text = seg[1] or ""
    local hl = seg[2]
    parts[#parts + 1] = text

    if hl then
      table.insert(marks, { col = col, end_col = col + #text, hl = hl })
    end

    col = col + #text
  end

  return table.concat(parts), marks
end

-- ============================================================================
-- Process table
-- ============================================================================

-- Left margin shared by the header box and the process table.
local TABLE_INDENT = "   "

-- Process table columns. Fixed-width columns keep the numeric metrics aligned;
-- `flex` columns split whatever horizontal space is left over.
local PROC_COLUMNS = {
  { title = "",         width = 4 },
  { title = "PID",      width = 8 },
  { title = "CWD",      flex = 3 },
  { title = "MEM(RSS)", width = 12, align = "right" },
  { title = "SUBSYSTEMS", flex = 4 },
  { title = "UPTIME",   width = 11 },
  { title = "BUFS",     width = 7,  align = "right" },
  { title = "PARSERS",  width = 9,  align = "right" },
}

-- Truncate keeping the head of the string ("long text…").
local function truncate_tail(text, max_width)
  if fn.strdisplaywidth(text) <= max_width then
    return text
  end

  local out = ""

  for _, char in ipairs(fn.split(text, "\\zs")) do
    if fn.strdisplaywidth(out .. char) > max_width - 1 then
      break
    end

    out = out .. char
  end

  return out .. "…"
end

-- Distribute the inner table width across fixed and flex columns.
local function resolve_column_widths(width)
  local inner = width - #TABLE_INDENT - (#PROC_COLUMNS + 1)
  local fixed, flex_total = 0, 0

  for _, col in ipairs(PROC_COLUMNS) do
    if col.width then
      fixed = fixed + col.width
    else
      flex_total = flex_total + col.flex
    end
  end

  local flex_space = math.max(#PROC_COLUMNS * 6, inner - fixed)
  local widths = {}
  local assigned = 0
  local last_flex

  for i, col in ipairs(PROC_COLUMNS) do
    if col.width then
      widths[i] = col.width
    else
      widths[i] = math.max(8, math.floor(flex_space * col.flex / flex_total))
      assigned = assigned + widths[i]
      last_flex = i
    end
  end

  -- The last flex column absorbs the rounding remainder so the right border
  -- lines up with the rules above and below it.
  if last_flex then
    widths[last_flex] = widths[last_flex] + (flex_space - assigned)
  end

  return widths
end

-- Horizontal rule spanning the table with the given corner/cross glyphs.
local function build_table_rule(widths, left, cross, right)
  local parts = { TABLE_INDENT, left }

  for i, w in ipairs(widths) do
    parts[#parts + 1] = string.rep("─", w)
    parts[#parts + 1] = (i < #widths) and cross or right
  end

  local line = table.concat(parts)

  return line, { { col = #TABLE_INDENT, end_col = #line, hl = "MemDashHeaderBorder" } }
end

-- One table row. `cells` is a list aligned with PROC_COLUMNS; a cell is either
-- a single `{ text, highlight }` pair or `{ segments = { {text, hl}, … } }` for
-- cells that mix highlights. Each cell is padded to its column width.
local function build_table_row(widths, cells)
  local parts = { TABLE_INDENT }
  local marks = {}
  local col = #TABLE_INDENT

  for i, w in ipairs(widths) do
    parts[#parts + 1] = "│"
    table.insert(marks, { col = col, end_col = col + #"│", hl = "MemDashHeaderBorder" })
    col = col + #"│"

    local cell = cells[i] or {}
    local segments = cell.segments or { { cell[1] or "", cell[2] } }
    local content_width = 0

    for _, seg in ipairs(segments) do
      seg[1] = truncate_tail(seg[1], math.max(1, w - 2 - content_width))
      content_width = content_width + fn.strdisplaywidth(seg[1])
    end

    local pad = math.max(0, w - 2 - content_width)
    local lead = (PROC_COLUMNS[i].align == "right") and pad + 1 or 1

    parts[#parts + 1] = string.rep(" ", lead)
    col = col + lead

    for _, seg in ipairs(segments) do
      parts[#parts + 1] = seg[1]

      if seg[1] ~= "" and seg[2] then
        table.insert(marks, { col = col, end_col = col + #seg[1], hl = seg[2] })
      end

      col = col + #seg[1]
    end

    local trail = w - lead - content_width
    parts[#parts + 1] = string.rep(" ", math.max(0, trail))
    col = col + math.max(0, trail)
  end

  parts[#parts + 1] = "│"
  table.insert(marks, { col = col, end_col = col + #"│", hl = "MemDashHeaderBorder" })

  return table.concat(parts), marks
end

-- tmux location of a process, e.g. "⧉ work:editor.2" (session : window name .
-- pane index). nil when the process isn't running inside tmux.
local function tmux_label(tmux)
  if not tmux then
    return nil
  end

  return string.format("⧉ %s:%s.%d", tmux.session, tmux.window_name, tmux.pane_index)
end

-- Width of a row that spans every column (column dividers become content).
local function span_width(widths)
  local total = #widths - 1

  for _, w in ipairs(widths) do
    total = total + w
  end

  return total
end

-- A full-width row inside the table, used for the buffer detail of an
-- expanded process. `left`/`right` are `{ text, highlight }` segment lists;
-- the gap between them is padded so the right group hugs the right border.
local function build_span_row(widths, left, right)
  local content_width = span_width(widths) - 2
  local left_width, right_width = 0, 0

  for _, seg in ipairs(left) do
    left_width = left_width + fn.strdisplaywidth(seg[1])
  end

  for _, seg in ipairs(right) do
    right_width = right_width + fn.strdisplaywidth(seg[1])
  end

  -- Overflow: shrink the last left segment (the name) rather than pushing the
  -- right border out of alignment.
  if left_width + right_width > content_width then
    local last = left[#left]
    local allowed = math.max(1,
      fn.strdisplaywidth(last[1]) - (left_width + right_width - content_width))
    left_width = left_width - fn.strdisplaywidth(last[1])
    last[1] = truncate_tail(last[1], allowed)
    left_width = left_width + fn.strdisplaywidth(last[1])
  end

  local parts = { TABLE_INDENT, "│", " " }
  local marks = { { col = #TABLE_INDENT, end_col = #TABLE_INDENT + #"│", hl = "MemDashHeaderBorder" } }
  local col = #TABLE_INDENT + #"│" + 1

  local function append(segments)
    for _, seg in ipairs(segments) do
      parts[#parts + 1] = seg[1]

      if seg[2] then
        table.insert(marks, { col = col, end_col = col + #seg[1], hl = seg[2] })
      end

      col = col + #seg[1]
    end
  end

  append(left)
  local gap = math.max(1, content_width - left_width - right_width)
  parts[#parts + 1] = string.rep(" ", gap)
  col = col + gap
  append(right)
  parts[#parts + 1] = " │"
  table.insert(marks, { col = col + 1, end_col = col + 1 + #"│", hl = "MemDashHeaderBorder" })

  return table.concat(parts), marks
end

-- One borderless stats line, right-aligned so it ends flush with the table's
-- table's left edge. `rows` is a list of rows, each a list of items
-- `{ label, value, value_highlight }`. Labels and values are padded to the
-- widest entry in their column, so both line up vertically across rows.
-- Returns a list of `{ line, marks }`.
local function build_stats_grid(rows)
  local label_widths, value_widths = {}, {}

  for _, items in ipairs(rows) do
    for i, item in ipairs(items) do
      label_widths[i] = math.max(label_widths[i] or 0, fn.strdisplaywidth(item[1]))
      value_widths[i] = math.max(value_widths[i] or 0, fn.strdisplaywidth(item[2]))
    end
  end

  local lines = {}

  for _, items in ipairs(rows) do
    local segments = { { TABLE_INDENT, nil } }

    for i, item in ipairs(items) do
      if i > 1 then
        table.insert(segments, { " · ", "MemDashSep" })
      end

      local label_pad = label_widths[i] - fn.strdisplaywidth(item[1])
      local value_pad = value_widths[i] - fn.strdisplaywidth(item[2])
      table.insert(segments, { item[1], "MemDashSummary" })
      table.insert(segments, { string.rep(" ", label_pad), nil })
      table.insert(segments, { "  ", nil })
      table.insert(segments, { item[2], item[3] or "MemDashMetric" })

      if i < #items then
        table.insert(segments, { string.rep(" ", value_pad), nil })
      end
    end

    local line, marks = build_line(segments)
    table.insert(lines, { line, marks })
  end

  return lines
end

-- Long-lived nvims accumulate memory, so the uptime column escalates:
-- yellow from 5 days, red from 2 weeks.
local UPTIME_WARN_SECONDS = 5 * 86400
local UPTIME_CRITICAL_SECONDS = 14 * 86400

local function uptime_hl(seconds)
  if not seconds then
    return "MemDashUptime"
  end

  if seconds >= UPTIME_CRITICAL_SECONDS then
    return "MemDashUptimeCritical"
  end

  if seconds >= UPTIME_WARN_SECONDS then
    return "MemDashUptimeWarn"
  end

  return "MemDashUptime"
end

-- Compact uptime for the table column ("3h 20m"); long form lives in the
-- process's expanded detail block.
local function fmt_uptime_short(seconds)
  if not seconds then return "?" end

  if seconds < 3600 then
    return string.format("%dm", math.floor(seconds / 60))
  end

  if seconds < 86400 then
    return string.format("%dh %dm", math.floor(seconds / 3600),
      math.floor((seconds % 3600) / 60))
  end

  return string.format("%dd %dh", math.floor(seconds / 86400),
    math.floor((seconds % 86400) / 3600))
end

-- Per-subsystem RSS breakdown rendered into one cell:
--   • LSP: real child-process RSS (sum + server names)
--   • TS:  ~estimate (source bytes × 3) + active languages
--   • Fugitive: real bytes from open fugitive buffers
--   • Lua: real heap from collectgarbage("count")
local function subsystem_text(p)
  local segments = {}
  local lsp_names = p.lsp_names or {}
  local lsp_procs = p.lsp_procs or { items = {}, total_kb = 0 }
  local ts_bytes = p.ts_bytes or 0
  local fug_count = p.fug_count or 0
  local fug_bytes = p.fug_bytes or 0

  if lsp_procs.total_kb > 0 then
    local names = {}

    for _, item in ipairs(lsp_procs.items) do
      table.insert(names, item.name)
    end

    table.insert(segments, string.format("LSP %s (%s)",
      utils.fmt_kb(lsp_procs.total_kb), table.concat(names, ", ")))
  elseif #lsp_names > 0 then
    table.insert(segments, string.format("LSP %d (%s)",
      #lsp_names, table.concat(lsp_names, ", ")))
  end

  if ts_bytes > 0 then
    table.insert(segments, string.format("TS ~%s",
      utils.fmt_kb(math.floor(ts_bytes * 3 / 1024))))
  end

  if fug_count > 0 then
    table.insert(segments, string.format("Fugitive %s",
      utils.fmt_kb(math.floor(fug_bytes / 1024))))
  end

  if p.lua_heap_kb then
    table.insert(segments, "Lua " .. utils.fmt_kb(p.lua_heap_kb))
  end

  return table.concat(segments, " · ")
end

-- ============================================================================
-- Render
-- ============================================================================

-- Build (lines, marks, row_index) from the per-process view-model.
local function render_view_model(view, width)
  local lines = {}
  local marks = {}
  local row_index = {}
  local sort_key = shared.dashboard_state.sort
  sort_processes(view, sort_key)

  -- Aggregate totals for the summary line.
  local total_loaded, total_parsers, total_rss = 0, 0, 0
  local current_proc, heaviest_proc

  for _, p in ipairs(view) do
    total_loaded = total_loaded + (p.loaded or 0)
    total_parsers = total_parsers + (p.parsers or 0)
    total_rss = total_rss + (p.rss_mb or 0)

    if p.is_current then
      current_proc = p
    end

    if not heaviest_proc or (p.rss_mb or 0) > (heaviest_proc.rss_mb or 0) then
      heaviest_proc = p
    end
  end

  local function push(line, marks_for_line, kind)
    table.insert(lines, line)
    local ln = #lines - 1

    for _, m in ipairs(marks_for_line or {}) do
      table.insert(marks, {
        line = ln, col = m.col, end_col = m.end_col, hl = m.hl,
      })
    end
    row_index[#lines] = kind or { kind = "blank" }
  end

  -- Vertical breathing room.
  push("", nil, { kind = "blank" })

  -- ------- Header banner (ASCII-table card with bg-tinted rows) -------
  local rss_now = stats.rss_mb() or 0
  local rss_hl = rss_now > cleaner.config.rss_warn_threshold_mb
    and "MemDashRSSWarn" or "MemDashRSS"

  -- Peak + trend over the 24h ring buffer; replaces the sparkline.
  local peak_mb, trend_glyph, trend_hl = nil, "—", "MemDashSummary"

  if #cleaner.rss_history > 0 then
    local mx = -math.huge

    for _, v in ipairs(cleaner.rss_history) do
      if v > mx then mx = v end
    end

    peak_mb = mx
  end

  if #cleaner.rss_history >= 3 then
    local sorted = vim.deepcopy(cleaner.rss_history)
    table.sort(sorted)
    local median = sorted[math.floor(#sorted / 2) + 1]
    local last = cleaner.rss_history[#cleaner.rss_history]
    local delta = (last - median) / math.max(1, median)

    if delta > 0.10 then
      trend_glyph, trend_hl = "↗ trending up", "MemDashRSSWarn"
    elseif delta < -0.10 then
      trend_glyph, trend_hl = "↘ trending down", "MemDashGood"
    else
      trend_glyph, trend_hl = "→ steady", "MemDashSummary"
    end
  end

  -- Format-duration helper used by the timings row.
  local cfg = cleaner.config
  local now_epoch = os.time()
  local prune_period = cfg.prune_tick_interval_seconds
  local rss_period = cfg.rss_history_sample_interval_seconds
  local next_prune = math.max(0,
    (cleaner.timer_state.last_prune_at + prune_period) - now_epoch)
  local next_sample = math.max(0,
    (cleaner.timer_state.last_rss_sample_at + rss_period) - now_epoch)

  local function fmt_dur(s)
    if s < 60 then
      return string.format("%ds", s)
    elseif s < 3600 then
      if s % 60 == 0 then return string.format("%dm", s / 60) end
      return string.format("%dm%02ds", math.floor(s / 60), s % 60)
    end
    return string.format("%dh%02dm", math.floor(s / 3600), math.floor((s % 3600) / 60))
  end

  -- ------- Stats strip: borderless, left-aligned with the table -------
  local widths = resolve_column_widths(width)
  local total_hl = total_rss > cleaner.config.rss_warn_threshold_mb * 4
    and "MemDashMetricWarn" or "MemDashMetric"
  local last_prune_at = cleaner.timer_state.last_prune_at
  local last_sample_at = cleaner.timer_state.last_rss_sample_at
  local setup_at = cleaner.timer_state.setup_at
  local parser_estimate_count = vim.tbl_count(cfg.parser_memory_estimate_kb_by_filetype)

  -- "5m ago" for an epoch timestamp; "never" when the timer hasn't fired yet.
  local function fmt_ago(epoch)
    if not epoch or epoch == 0 then
      return "never"
    end

    return fmt_dur(math.max(0, now_epoch - epoch)) .. " ago"
  end

  -- Section boundary — the label embedded in a horizontal rule spanning the
  -- same width as the process table — then its stats grid and a blank line.
  local function push_section(label, rows)
    local rule_width = span_width(widths) + 2
    local tail = math.max(0, rule_width - 4 - fn.strdisplaywidth(label))
    local label_line, label_marks = build_line({
      { TABLE_INDENT, nil },
      { "── ", "MemDashHeaderBorder" },
      { label, "MemDashSection" },
      { " " .. string.rep("─", tail), "MemDashHeaderBorder" },
    })
    push(label_line, label_marks, { kind = "header" })

    for _, stat_line in ipairs(build_stats_grid(rows)) do
      push(stat_line[1], stat_line[2], { kind = "header" })
    end

    push("", nil, { kind = "blank" })
  end

  push_section("THIS NVIM", {
    {
      { "Mem(RSS)", utils.fmt_mb(rss_now) or "—", rss_hl },
      { "Peak 24h", utils.fmt_mb(peak_mb) or "—", "MemDashMetric" },
      { "Trend", trend_glyph, trend_hl },
      { "Buffers", string.format("%d (%d parsers)",
        current_proc and current_proc.loaded or 0,
        current_proc and current_proc.parsers or 0), "MemDashMetric" },
      { "Uptime", fmt_uptime_short(current_proc and current_proc.uptime_seconds),
        uptime_hl(current_proc and current_proc.uptime_seconds) },
    },
  })

  push_section("ALL NVIM PROCESSES", {
    {
      { "Total Mem(RSS)", utils.fmt_mb(total_rss) or "—", total_hl },
      { "Processes", tostring(#view), "MemDashMetric" },
      { "Buffers", tostring(total_loaded), "MemDashMetric" },
      { "Parsers", tostring(total_parsers), "MemDashMetric" },
    },
    {
      { "Average Mem(RSS)", utils.fmt_mb(#view > 0 and (total_rss / #view) or 0) or "—",
        "MemDashMetric" },
      { "Heaviest", heaviest_proc
        and string.format("pid %d · %s", heaviest_proc.pid,
          utils.fmt_mb(heaviest_proc.rss_mb) or "?")
        or "—", "MemDashMetric" },
      { "Sort", string.format("%s ↻", sort_key), "MemDashSortKey" },
    },
  })

  push_section("MEMORY CLEANER", {
    {
      { "Unload buffer after idle", fmt_dur(cfg.unload_buffer_after_idle_minutes * 60), "MemDashMetric" },
      { "Prune every", string.format("%s (next in %s)", fmt_dur(prune_period), fmt_dur(next_prune)), "MemDashMetric" },
      { "Sample every", string.format("%s (next in %s)", fmt_dur(rss_period), fmt_dur(next_sample)), "MemDashMetric" },
      { "Warn at", utils.fmt_mb(cfg.rss_warn_threshold_mb) or "—", "MemDashMetric" },
    },
    {
      { "Last prune", fmt_ago(last_prune_at), "MemDashMetric" },
      { "Last sample", fmt_ago(last_sample_at), "MemDashMetric" },
      { "Warn cooldown", fmt_dur(cfg.rss_warn_notify_debounce_seconds), "MemDashMetric" },
      { "In breach", cleaner.notify_state.in_breach and "yes" or "no",
        cleaner.notify_state.in_breach and "MemDashMetricWarn" or "MemDashGood" },
    },
    {
      { "Loaded", fmt_ago(setup_at), "MemDashMetric" },
      { "RSS cache", fmt_dur(cfg.rss_reading_cache_seconds), "MemDashMetric" },
      { "History", string.format("%d/%d samples (%s)", #cleaner.rss_history,
        cfg.rss_history_max_samples,
        fmt_dur(cfg.rss_history_max_samples * rss_period)), "MemDashMetric" },
      { "Parser estimates", string.format("%d filetypes", parser_estimate_count), "MemDashMetric" },
    },
    {
      { "Keep LSP", table.concat(cfg.lsp_clients_never_auto_stop, ", "), "MemDashMetric" },
      { "History file", shorten_path(cfg.rss_history_state_path, 46), "MemDashMetricDim" },
    },
  })

  push("", nil, { kind = "blank" })

  -- ------- Process table: exactly one row per nvim process -------
  local cwd_width = widths[3] - 2

  local function push_table_line(line, line_marks)
    push(line, line_marks, { kind = "header" })
  end

  push_table_line(build_table_rule(widths, "╭", "┬", "╮"))
  push_table_line(build_table_row(widths, {
    {},
    { "PID", "MemDashSummary" },
    { "CWD", "MemDashSummary" },
    { "MEM(RSS)", "MemDashSummary" },
    { "SUBSYSTEMS", "MemDashSummary" },
    { "UPTIME", "MemDashSummary" },
    { "BUFS", "MemDashSummary" },
    { "PARSERS", "MemDashSummary" },
  }))
  push_table_line(build_table_rule(widths, "├", "┼", "┤"))

  -- Buffer rows of an expanded process, rendered as full-width rows nested
  -- inside the table right below that process's row.
  local function push_buffer_rows(p)
    local by_section = { Visible = {}, ["Loaded-Hidden"] = {}, Unloaded = {}, Special = {} }

    for _, b in ipairs(p.buffers or {}) do
      table.insert(by_section[section_of(b)], b)
    end

    for _, sec_name in ipairs(SECTION_ORDER) do
      local items = by_section[sec_name]

      if #items > 0 then
        sort_buffers(items, sort_key)
        local sec_line, sec_marks = build_span_row(widths, {
          { "  ", nil },
          { sec_name, "MemDashSection" },
          { string.format(" · %d", #items), "MemDashSectionCount" },
        }, {})
        push(sec_line, sec_marks, { kind = "section", pid = p.pid, proc = p, section = sec_name })

        for _, b in ipairs(items) do
          local idle_text

          if b.idle_min and b.idle_min > 0 then
            idle_text = string.format("%4dm idle", b.idle_min)
          else
            idle_text = "   – idle"
          end

          local buf_hl = b.modified and "MemDashBufModified"
            or (b.loaded and "MemDashBuf" or "MemDashBufDim")
          local left_segs = {
            { "    ", nil },
            { status_glyph(b), b.modified and "MemDashBufModified" or "MemDashSep" },
            { "  ", nil },
            { (b.name:gsub(vim.env.HOME or "~", "~")), buf_hl },
          }
          local right_segs = {
            { string.format("%6dL", b.line_count or 0), "MemDashMetricDim" },
            { "   ", nil },
            { idle_text, "MemDashIdle" },
            { "   ", nil },
            { string.format("%9s", utils.fmt_kb(b.est_kb)), "MemDashEst" },
          }
          local row_l, row_m = build_span_row(widths, left_segs, right_segs)
          push(row_l, row_m, { kind = "buffer", pid = p.pid, proc = p, buffer = b })
        end
      end
    end
  end

  for proc_index, p in ipairs(view) do
    local is_current = p.is_current
    local rss_hl_proc = (p.rss_mb and p.rss_mb > cleaner.config.rss_warn_threshold_mb)
      and "MemDashMetricWarn" or "MemDashMetric"
    local detail = p.error and ("⚠ " .. tostring(p.error)) or subsystem_text(p)
    local detail_hl = p.error and "MemDashError" or "MemDashUptime"
    local pane = tmux_label(p.tmux)

    local row_line, row_marks = build_table_row(widths, {
      { fold_glyph(p.pid) .. (is_current and "★" or " "),
        is_current and "MemDashCurrent" or "MemDashSep" },
      { tostring(p.pid), "MemDashPid" },
      { shorten_path(p.cwd, cwd_width),
        is_current and "MemDashCurrent" or "MemDashCwd" },
      { utils.fmt_mb(p.rss_mb) or "?", rss_hl_proc },
      { detail, detail_hl },
      { fmt_uptime_short(p.uptime_seconds), uptime_hl(p.uptime_seconds) },
      { tostring(p.loaded or 0), "MemDashMetric" },
      { tostring(p.parsers or 0), "MemDashMetricDim" },
    })
    push(row_line, row_marks, { kind = "proc", pid = p.pid, proc = p })

    -- tmux location gets its own row under the path, in the CWD column;
    -- tagged as the same proc row so fold/kill keymaps work on it too.
    if pane then
      local tmux_line, tmux_marks = build_table_row(widths, {
        {}, {},
        { pane, "MemDashTmux" },
        {}, {}, {}, {}, {},
      })
      push(tmux_line, tmux_marks, { kind = "proc", pid = p.pid, proc = p })
    end

    local expanded = not shared.dashboard_state.folded[p.pid]
      and not p.error
      and #(p.buffers or {}) > 0
    local is_last = proc_index == #view

    if expanded then
      -- Merge the columns away for the detail block, then split them back for
      -- the next process row (or close the table if this was the last one).
      push_table_line(build_table_rule(widths, "├", "┴", "┤"))
      push_buffer_rows(p)

      if is_last then
        push_table_line(build_table_rule(widths, "╰", "─", "╯"))
      else
        push_table_line(build_table_rule(widths, "├", "┬", "┤"))
      end
    elseif is_last then
      push_table_line(build_table_rule(widths, "╰", "┴", "╯"))
    end
  end

  -- Trailing blank lines so content never sits visually behind the fixed
  -- bottom hint overlay even when the buffer is short.
  for _ = 1, 3 do
    push("", nil, { kind = "blank" })
  end

  return lines, marks, row_index
end

-- Footer for the dashboard float. Rendered along the bottom border by nvim,
-- so the hint is always pinned to the very bottom of the window regardless
-- of scroll position. Returns a list of `{text, hl_group}` pairs.
local function build_footer()
  return {
    { " ", "FloatFooter" },
    { "q", "MemDashHintKey" }, { " close · ", "MemDashHint" },
    { "r", "MemDashHintKey" }, { " refresh · ", "MemDashHint" },
    { "?", "MemDashHintKey" }, { " help · ", "MemDashHint" },
    { "⇥", "MemDashHintKey" }, { " fold · ", "MemDashHint" },
    { "s", "MemDashHintKey" }, { " sort · ", "MemDashHint" },
    { "u/w/W", "MemDashHintKey" }, { " unload/wipe/force-wipe · ", "MemDashHint" },
    { "U", "MemDashHintKey" }, { " section · ", "MemDashHint" },
    { "X", "MemDashHintKey" }, { " all · ", "MemDashHint" },
    { "x", "MemDashHintKey" }, { " kill · ", "MemDashHint" },
    { "↵", "MemDashHintKey" }, { " jump ", "MemDashHint" },
  }
end

-- Apply lines + marks under our namespace (clear-then-paint).
local function paint(buf, lines, marks, row_index)
  -- nvim_buf_set_lines rejects strings containing newlines; sanitize any
  -- stray newline that slipped in from `ps`, `lsof`, remote JSON, or a buf
  -- name. Replace with a single space to keep column offsets stable.
  for i, l in ipairs(lines) do
    if type(l) == "string" and l:find("[\r\n]") then
      lines[i] = (l:gsub("[\r\n]+", " "))
    end
  end

  vim.bo[buf].modifiable = true
  api.nvim_buf_clear_namespace(buf, NS, 0, -1)
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  for _, m in ipairs(marks) do
    local opts = { hl_group = m.hl }

    if m.hl_eol then
      opts.hl_eol = true
      -- A line-wide bg covering the whole row: end_col == byte length.
      opts.end_col = #(lines[m.line + 1] or "")
    elseif m.end_col and m.end_col > 0 then
      opts.end_col = m.end_col
    else
      opts.end_col = m.col + 1
    end

    if m.priority then
      opts.priority = m.priority
    end

    pcall(api.nvim_buf_set_extmark, buf, NS, m.line, m.col, opts)
  end

  vim.bo[buf].modifiable = false
  shared.dashboard_state.row_index = row_index
end

-- ============================================================================
-- Open / refresh / re-render
-- ============================================================================

-- Compute window inner width once per render.
local function inner_width()
  if shared.dashboard_state.win and api.nvim_win_is_valid(shared.dashboard_state.win) then
    return api.nvim_win_get_width(shared.dashboard_state.win)
  end

  return math.max(40, vim.o.columns - 2)
end

-- Re-render only (cheap: no RPC, no re-discovery; called by sort/fold).
local function rerender()
  local view = shared.dashboard_state.view or {}
  local lines, marks, row_index = render_view_model(view, inner_width())
  paint(shared.dashboard_state.buf, lines, marks, row_index)
end

-- Paint a placeholder "loading" state while the synchronous discovery +
-- per-process snapshots run. The full refresh blocks for ~200–500ms while
-- shelling out to pgrep/ps/lsof and rpc-querying each sibling nvim; this
-- gives the user immediate visual feedback that the popup is alive.
local function paint_loading()
  local buf = shared.dashboard_state.buf

  if not buf or not api.nvim_buf_is_valid(buf) then
    return
  end

  local lines = {
    "",
    "      ⏳  Discovering nvim processes and gathering memory stats…",
    "",
    "      This usually takes under a second.",
    "",
  }
  local marks = {
    { line = 1, col = 0, end_col = #lines[2], hl = "MemDashTitle" },
    { line = 3, col = 0, end_col = #lines[4], hl = "MemDashSummary" },
  }
  paint(buf, lines, marks, {})
end

-- Re-discover sibling sockets, fetch stats, then paint (called by `r`).
local function refresh()
  local processes = rpc.discover_processes()

  -- Default: current process expanded, others folded.
  for _, p in ipairs(processes) do
    if shared.dashboard_state.folded[p.pid] == nil then
      -- Every process (including current) starts folded for a clean overview;
      -- expand individually with <Tab> / <CR>.
      shared.dashboard_state.folded[p.pid] = true
    end
  end

  local view = {}

  for _, p in ipairs(processes) do
    local ok, snapshot = pcall(rpc.stats_remote, p)

    if ok and snapshot then
      snapshot.is_current = p.is_current
      snapshot.socket = p.socket
      table.insert(view, snapshot)
    end
  end

  cleaner.buf_bytes_cache = {}
  shared.dashboard_state.view = view
  rerender()
end
M.refresh = refresh

-- Row metadata under cursor (or nil for sep/blank).
local function row_at_cursor()
  local win = shared.dashboard_state.win

  if not win or not api.nvim_win_is_valid(win) then
    return nil
  end

  local lnum = api.nvim_win_get_cursor(win)[1]

  return shared.dashboard_state.row_index[lnum]
end

-- ============================================================================
-- Help float
-- ============================================================================

-- Help content: keybindings plus what every column / stat in the dashboard
-- actually means. Each section is `{ title, { { term, explanation }, … } }`.
local HELP_SECTIONS = {
  { "KEYBINDINGS", {
    { "q / <Esc>", "close dashboard" },
    { "r", "refresh (re-discover processes + re-render)" },
    { "?", "this help" },
    { "<Tab>", "toggle fold under cursor" },
    { "<CR>", "toggle fold (proc row) or jump to buffer" },
    { "s", "cycle sort key: size → idle → name (sorts processes and buffers)" },
    { "u", "unload buffer under cursor (keeps it listed)" },
    { "w", "wipe buffer under cursor (refuses if modified)" },
    { "W", "force-wipe buffer under cursor (ignores modified)" },
    { "U", "unload all buffers in the section under cursor" },
    { "X", "prune every nvim process (confirm)" },
    { "x", "kill the remote nvim under cursor (confirm)" },
  } },
  { "THIS NVIM", {
    { "Mem(RSS)", "resident memory of this nvim process, right now" },
    { "Peak 24h", "highest RSS in the 24h sample ring" },
    { "Trend", "latest RSS vs the ring's median (±10% = steady)" },
    { "Buffers", "loaded buffers / active treesitter parsers here" },
    { "Uptime", "age of this process" },
  } },
  { "ALL NVIM PROCESSES", {
    { "Total Mem(RSS)", "summed RSS of every discovered nvim process" },
    { "Processes", "how many nvim processes were discovered" },
    { "Buffers", "loaded buffers across all of them" },
    { "Parsers", "active treesitter parsers across all of them" },
    { "Average Mem(RSS)", "total RSS divided by process count" },
    { "Heaviest", "pid and RSS of the largest nvim process" },
    { "Sort", "sort key for the process table and buffer lists (cycle with s)" },
  } },
  { "WHAT A PRUNE CLEARS", {
    { "Buffer text", "idle buffers are :bunloaded — text freed, buffer stays listed" },
    { "TS parsers", "vim.treesitter.stop() on each buffer before it is unloaded" },
    { "LSP clients", "a client is stopped once its last attached buffer is gone" },
    { "Never touched", "visible buffers, modified buffers, special buftypes" },
    { "Never stopped", "LSP clients listed in Keep LSP (eslint, copilot, …)" },
    { "Reclaim estimate", "buffer bytes + a per-filetype parser estimate (see EST column)" },
    { "Runs when", "the prune timer fires, or on X / U, or via :MemClear" },
  } },
  { "MEMORY CLEANER", {
    { "Unload buffer after idle", "a buffer untouched this long is unloaded on the next prune" },
    { "Prune every", "prune-timer period, and the countdown to its next run" },
    { "Sample every", "how often RSS is appended to the history ring" },
    { "Warn at", "RSS threshold that fires the warning notification" },
    { "Warn cooldown", "minimum gap between two warning notifications" },
    { "In breach", "yes while RSS sits above the warn threshold" },
    { "Last prune", "time since the prune timer last fired" },
    { "Last sample", "time since RSS was last appended to the ring" },
    { "Loaded", "time since memory_cleaner.setup() ran" },
    { "RSS cache", "how long one RSS reading is reused before re-shelling out" },
    { "History", "samples stored / ring capacity (and the window it covers)" },
    { "Parser estimates", "filetypes with a KB-per-parser memory estimate" },
    { "Keep LSP", "clients never auto-stopped when their last buffer unloads" },
  } },
  { "PROCESS TABLE", {
    { "CWD", "working directory; ⧉ session:window.pane on the row below when in tmux" },
    { "SUBSYSTEMS", "LSP child-process RSS, TS ≈ source bytes × 3, fugitive, Lua heap" },
    { "UPTIME", "process age — yellow from 5 days, red from 2 weeks" },
    { "BUFS / PARSERS", "loaded buffers and active treesitter parsers" },
    { "▾ / ▸", "expanded / folded; ★ marks this nvim" },
  } },
  { "BUFFER GLYPHS", {
    { "●", "visible in a window" },
    { "◐", "loaded but hidden" },
    { "○", "listed but unloaded" },
    { "!", "modified (wipe refuses; W forces)" },
    { "*", "special buftype (terminal, quickfix, …)" },
  } },
}

-- Open a centered help float; close on any key.
local function open_help_float()
  local term_width = 26
  local body = { "" }
  local marks = {}

  for section_index, section in ipairs(HELP_SECTIONS) do
    if section_index > 1 then
      table.insert(body, "")
    end

    table.insert(body, "  " .. section[1])
    table.insert(marks, { line = #body - 1, col = 2, end_col = 2 + #section[1],
      hl = "MemDashSection" })

    for _, row in ipairs(section[2]) do
      local pad = math.max(1, term_width - fn.strdisplaywidth(row[1]))
      local line = "    " .. row[1] .. string.rep(" ", pad) .. row[2]
      table.insert(body, line)
      table.insert(marks, { line = #body - 1, col = 4, end_col = 4 + #row[1],
        hl = "MemDashHintKey" })
      table.insert(marks, { line = #body - 1, col = 4 + #row[1] + pad, end_col = #line,
        hl = "MemDashHint" })
    end
  end

  table.insert(body, "")
  table.insert(body, "  any key closes this help")
  table.insert(body, "")

  local width = math.min(94, vim.o.columns - 6)
  local height = math.min(#body, vim.o.lines - 6)
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(buf, 0, -1, false, body)
  vim.bo[buf].modifiable = false
  local win = api.nvim_open_win(buf, true, {
    relative = "editor", width = width, height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    border = "rounded", title = "  Memory Manager — help  ", title_pos = "center",
  })
  vim.wo[win].wrap = false
  vim.wo[win].cursorline = false
  local hns = api.nvim_create_namespace("MemDashboardHelp")

  for _, m in ipairs(marks) do
    api.nvim_buf_set_extmark(buf, hns, m.line, m.col,
      { end_col = m.end_col, hl_group = m.hl })
  end

  local function close_help()
    if api.nvim_win_is_valid(win) then api.nvim_win_close(win, true) end
  end

  -- Any key closes the help float, except the motions needed to scroll it.
  for _, k in ipairs({ "q", "<Esc>", "?", "<CR>", "<Space>", "h", "l" }) do
    vim.keymap.set("n", k, close_help, { buffer = buf, nowait = true, silent = true })
  end
end

-- ============================================================================
-- Actions
-- ============================================================================

-- Close the dashboard window (BufWipeout autocmd handles channel + hint cleanup).
local function close_dashboard()
  if shared.dashboard_state.win and api.nvim_win_is_valid(shared.dashboard_state.win) then
    api.nvim_win_close(shared.dashboard_state.win, true)
  end
end

-- Create / paint the fixed bottom hint floating window overlay.
-- (Hint is now rendered as the floating window's footer; no overlay needed.)

-- u/w/W: unload, wipe, or force-wipe buffer under cursor (local or remote).
-- "wipe" honors the modified flag; "force_wipe" overrides it (:bwipeout!).
local function action_buffer(verb)
  local row = row_at_cursor()
  if not row or row.kind ~= "buffer" then return end
  local b, proc = row.buffer, row.proc
  local opts
  if verb == "unload" then
    opts = { unload = true }
  elseif verb == "force_wipe" then
    opts = { force = true }
  else
    opts = { force = false }
  end

  if proc.is_current then
    pcall(api.nvim_buf_delete, b.bufnr, opts)
  else
    rpc.remote_buf_delete(proc.socket, b.bufnr, opts)
  end

  refresh()
end

-- U: prune the section under cursor (local pass or remote `:MemClear 0`).
local function action_section_unload()
  local row = row_at_cursor()
  if not row or row.kind ~= "section" then return end
  local proc = row.proc

  if proc.is_current then
    prune.prune({ force_minutes = 0 })
  else
    rpc.remote_exec(proc.socket, "MemClear 0")
  end

  refresh()
end

-- X: prune everywhere after a confirm; sends `MemClear 0` to every process.
local function action_prune_all()
  local choice = fn.confirm("Prune all nvim processes?", "&Yes\n&No", 2)
  if choice ~= 1 then return end
  prune.prune({ force_minutes = 0 })

  for _, p in ipairs(shared.dashboard_state.view or {}) do
    if not p.is_current and p.socket then
      rpc.remote_exec(p.socket, "MemClear 0")
    end
  end

  refresh()
end

-- x: kill remote nvim under cursor (y/n confirm); sends :qa! via vim.system.
local function action_kill_remote()
  local row = row_at_cursor()
  if not row or row.kind ~= "proc" then return end
  local proc = row.proc

  if proc.is_current then
    vim.notify("[mem] use :qa yourself to quit the current nvim", vim.log.levels.WARN)
    return
  end

  local cwd_short = proc.cwd or "?"
  local choice = fn.confirm(
    string.format("Kill nvim pid %d (%s)?", proc.pid, cwd_short),
    "&Yes\n&No", 2)

  if choice == 1 then
    rpc.remote_exec(proc.socket, "qa!")
    vim.defer_fn(refresh, 300)
  end
end

-- <Tab>: toggle fold for the process the cursor is inside.
local function action_toggle_fold()
  local row = row_at_cursor()
  if not row or not row.pid then return end
  shared.dashboard_state.folded[row.pid] = not shared.dashboard_state.folded[row.pid]
  rerender()
end

-- <CR>: on a process row, toggle fold (same as <Tab>); on a buffer row,
-- jump to the local buffer; on a remote buffer row, print a hint.
local function action_jump()
  local row = row_at_cursor()
  if not row then return end

  if row.kind == "proc" or row.kind == "section" then
    action_toggle_fold()
    return
  end

  if row.kind ~= "buffer" then return end

  if row.proc.is_current then
    close_dashboard()
    vim.cmd("buffer " .. row.buffer.bufnr)
  else
    vim.notify("[mem] remote buffer — switch to that nvim to open", vim.log.levels.INFO)
  end
end

-- s: cycle the sort key (size → idle → name → size).
local function action_cycle_sort()
  local order = { size = "idle", idle = "name", name = "size" }
  shared.dashboard_state.sort = order[shared.dashboard_state.sort] or "size"
  rerender()
end

-- Bind buffer-local keys onto the dashboard buffer.
local function bind_keys(buf)
  local opts = { buffer = buf, nowait = true, silent = true }
  vim.keymap.set("n", "q", close_dashboard, opts)
  vim.keymap.set("n", "<Esc>", close_dashboard, opts)
  vim.keymap.set("n", "r", refresh, opts)
  vim.keymap.set("n", "?", open_help_float, opts)
  vim.keymap.set("n", "<Tab>", action_toggle_fold, opts)
  vim.keymap.set("n", "s", action_cycle_sort, opts)
  vim.keymap.set("n", "u", function() action_buffer("unload") end, opts)
  vim.keymap.set("n", "w", function() action_buffer("wipe") end, opts)
  vim.keymap.set("n", "W", function() action_buffer("force_wipe") end, opts)
  vim.keymap.set("n", "U", action_section_unload, opts)
  vim.keymap.set("n", "X", action_prune_all, opts)
  vim.keymap.set("n", "x", action_kill_remote, opts)
  vim.keymap.set("n", "<CR>", action_jump, opts)
end

-- Geometry for the float: full editor width (minus the border cells),
-- vertically centered at 85% height.
local function float_geometry()
  local width = math.max(40, vim.o.columns - 2)
  local height = math.floor(vim.o.lines * 0.85)

  return {
    relative = "editor", width = width, height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
  }
end

-- Re-fit the float to the resized editor grid, then re-render (inner width
-- changed, so wrapped/truncated rows must be recomputed).
local function resize_to_editor()
  local win = shared.dashboard_state.win

  if not win or not api.nvim_win_is_valid(win) then
    return
  end

  api.nvim_win_set_config(win, float_geometry())
  rerender()
end

-- Open the dashboard float (idempotent: focuses + refreshes if already open).
function M.open()
  ensure_highlights()

  if shared.dashboard_state.win and api.nvim_win_is_valid(shared.dashboard_state.win) then
    api.nvim_set_current_win(shared.dashboard_state.win)
    refresh()
    return
  end

  local buf = api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "MemDashboard"
  local geometry = float_geometry()
  geometry.border = "rounded"
  geometry.title = "  Memory Manager  "
  geometry.title_pos = "center"
  -- Footer renders inside the bottom border of the float — always pinned
  -- to the very bottom of the window regardless of scroll.
  geometry.footer = build_footer()
  geometry.footer_pos = "center"
  local win = api.nvim_open_win(buf, true, geometry)
  vim.wo[win].cursorline = true
  vim.wo[win].wrap = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].fillchars = "eob: "
  vim.wo[win].scrolloff = 2
  shared.dashboard_state.buf = buf
  shared.dashboard_state.win = win
  bind_keys(buf)

  -- Keep the centered float fitted to the editor when the terminal/UI grid
  -- changes size; cleared on close so the global autocmd doesn't leak.
  local resize_group = api.nvim_create_augroup("MemDashboardResize", { clear = true })

  api.nvim_create_autocmd("VimResized", {
    group = resize_group,
    callback = resize_to_editor,
  })

  api.nvim_create_autocmd("BufWipeout", {
    buffer = buf,
    callback = function()
      api.nvim_del_augroup_by_id(resize_group)
      shared.dashboard_state.win = nil
      shared.dashboard_state.buf = nil
    end,
  })

  -- Paint a "Loading…" placeholder immediately, then defer the (slow)
  -- discovery + RPC sweep to the next event-loop tick so the float renders
  -- before we block on subprocess calls. From the user's perspective the
  -- popup pops, then fills in.
  paint_loading()
  vim.schedule(refresh)
end

return M
