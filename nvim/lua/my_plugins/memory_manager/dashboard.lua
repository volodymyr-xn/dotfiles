-- Cross-process Memory Manager dashboard: floating window + render + keymaps.
--
-- Design notes (after the round-1 UI review):
--   * The floating window's title bar already says "Memory Manager"; no
--     duplicated heading line inside the buffer.
--   * Per-process rows are single-line cards with right-aligned metrics so
--     pid / cwd / RSS / loaded / parsers line up vertically across rows.
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
-- Render
-- ============================================================================

-- Build (lines, marks, row_index) from the per-process view-model.
local function render_view_model(view, width)
  local lines = {}
  local marks = {}
  local row_index = {}
  local sort_key = shared.dashboard_state.sort

  -- Aggregate totals for the summary line.
  local total_loaded, total_parsers, total_rss = 0, 0, 0

  for _, p in ipairs(view) do
    total_loaded = total_loaded + (p.loaded or 0)
    total_parsers = total_parsers + (p.parsers or 0)
    total_rss = total_rss + (p.rss_mb or 0)
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
  local rss_hl = rss_now > cleaner.config.rss_warn_mb and "MemDashRSSWarn" or "MemDashRSS"

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
  local prune_period = math.floor(cfg.timer_interval_ms / 1000)
  local rss_period = math.floor(cfg.rss_sample_interval_ms / 1000)
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

  -- Box geometry: 4-column × 3-row grid.
  local indent = "   "
  local n_cols = 4
  local box_w = math.max(60, width - #indent * 2)
  -- Each column gets an equal slice of the inner width; the last column
  -- absorbs any rounding remainder so dividers align perfectly.
  local cell_w = math.floor((box_w - 2 - (n_cols - 1)) / n_cols)
  local last_cell_w = (box_w - 2 - (n_cols - 1)) - cell_w * (n_cols - 1)

  local function col_widths()
    local ws = {}

    for i = 1, n_cols do
      ws[i] = (i == n_cols) and last_cell_w or cell_w
    end

    return ws
  end

  -- Build a horizontal box-rule line with given corners + cross.
  local function rule(left, cross, right)
    local parts = { left }
    local ws = col_widths()

    for i = 1, n_cols do
      parts[#parts + 1] = string.rep("─", ws[i])

      if i < n_cols then
        parts[#parts + 1] = cross
      end
    end

    parts[#parts + 1] = right
    return indent .. table.concat(parts)
  end

  -- Push a rule line with FloatBorder highlight; no bg tint.
  local function push_rule(left, cross, right)
    local line = rule(left, cross, right)
    push(line, {
      { col = #indent, end_col = #line, hl = "MemDashHeaderBorder" },
    }, { kind = "header" })
  end

  -- Render one data row of 4 cells. Each cell is `{label, value, value_hl}`.
  -- Labels are dim; values use the caller-provided highlight.
  local function push_data_row(cells)
    local ws = col_widths()
    local parts = { "│" }
    local marks_for_line = {}
    -- Byte offset of the *next* segment to push into `parts`.
    local col = #indent + #"│"
    -- Left │.
    table.insert(marks_for_line, {
      col = #indent, end_col = #indent + #"│", hl = "MemDashHeaderBorder",
    })

    for i = 1, n_cols do
      local label = cells[i] and cells[i][1] or ""
      local value = cells[i] and cells[i][2] or ""
      local value_hl = cells[i] and cells[i][3] or "MemDashMetric"
      local w = ws[i]
      -- " label  value <pad> "
      local pad_left = " "
      local sep = "  "
      local label_dw = vim.fn.strdisplaywidth(label)
      local value_dw = vim.fn.strdisplaywidth(value)
      local used = #pad_left + label_dw + #sep + value_dw + #" "
      local pad_right = math.max(0, w - used)
      -- Add the leading single-space inside the cell.
      parts[#parts + 1] = pad_left
      col = col + #pad_left
      -- Label segment.
      parts[#parts + 1] = label

      if label ~= "" then
        table.insert(marks_for_line, {
          col = col, end_col = col + #label, hl = "MemDashSummary",
        })
      end

      col = col + #label
      -- "  " separator between label and value.
      parts[#parts + 1] = sep
      col = col + #sep
      -- Value segment with its own highlight.
      parts[#parts + 1] = value

      if value ~= "" then
        table.insert(marks_for_line, {
          col = col, end_col = col + #value, hl = value_hl,
        })
      end

      col = col + #value
      -- Trailing pad + cell-end space.
      parts[#parts + 1] = string.rep(" ", pad_right) .. " "
      col = col + pad_right + 1
      -- Divider │ between columns; right │ at the end.
      parts[#parts + 1] = "│"
      table.insert(marks_for_line, {
        col = col, end_col = col + #"│", hl = "MemDashHeaderBorder",
      })
      col = col + #"│"
    end

    local line = indent .. table.concat(parts)
    push(line, marks_for_line, { kind = "header" })
  end

  -- Top border.
  push_rule("╭", "┬", "╮")

  -- Row 1: instant state.
  local total_hl = total_rss > cleaner.config.rss_warn_mb * 4
    and "MemDashMetricWarn" or "MemDashMetric"
  push_data_row({
    { "RSS",        string.format("%dM", rss_now), rss_hl },
    { "Peak 24h",   peak_mb and string.format("%dM", peak_mb) or "—", "MemDashMetric" },
    { "Trend",      trend_glyph, trend_hl },
    { "Total",      string.format("%dM (%d nvim)", total_rss, #view), total_hl },
  })
  push_rule("├", "┼", "┤")

  -- Row 2: counts.
  push_data_row({
    { "Procs",      tostring(#view),                       "MemDashMetric" },
    { "Buffers",    tostring(total_loaded),                "MemDashMetric" },
    { "Parsers",    tostring(total_parsers),               "MemDashMetric" },
    { "Sort",       string.format("%s ↻", sort_key),       "MemDashSortKey" },
  })
  push_rule("├", "┼", "┤")

  -- Row 3: timings.
  push_data_row({
    { "Idle ≥",     fmt_dur(cfg.idle_minutes * 60),                       "MemDashMetric" },
    { "Prune",      string.format("%s / %s", fmt_dur(prune_period), fmt_dur(next_prune)),  "MemDashMetric" },
    { "Sample",     string.format("%s / %s", fmt_dur(rss_period), fmt_dur(next_sample)),   "MemDashMetric" },
    { "Warn cooldown", fmt_dur(cfg.notify_debounce_seconds),              "MemDashMetric" },
  })

  push_rule("╰", "┴", "╯")
  push("", nil, { kind = "blank" })

  -- ------- Per-process rows -------
  for proc_index, p in ipairs(view) do
    local is_current = p.is_current
    local marker = is_current and "★" or " "
    local fold = fold_glyph(p.pid)
    local pid_text = string.format("%-6s", tostring(p.pid))
    local cwd_max = math.max(20, width - 50)
    local cwd_text = shorten_path(p.cwd, cwd_max)

    -- Right side metrics, right-aligned to width.
    local rss_text = string.format("%4sM", tostring(p.rss_mb or "?"))
    local rss_metric_hl = (p.rss_mb and p.rss_mb > cleaner.config.rss_warn_mb)
      and "MemDashMetricWarn" or "MemDashMetric"
    local loaded_text = string.format("%3dL", p.loaded or 0)
    local parser_text = string.format("%3dP", p.parsers or 0)

    -- Left half segments.
    local left = {
      { "  ", nil },
      { fold, "MemDashSep" },
      { " ", nil },
      { marker, is_current and "MemDashCurrent" or "MemDashRemote" },
      { " ", nil },
      { pid_text, "MemDashPid" },
      { "  ", nil },
      { cwd_text, is_current and "MemDashCurrent" or "MemDashCwd" },
    }
    local left_concat = ""

    for _, seg in ipairs(left) do
      left_concat = left_concat .. (seg[1] or "")
    end

    -- Right half: rss / loaded / parsers, separated by two spaces.
    local right_pieces = { rss_text, loaded_text, parser_text }
    local right_concat = "   " .. rss_text .. "   " .. loaded_text .. "   " .. parser_text .. " "
    local fill = math.max(1, width - #left_concat - #right_concat)

    table.insert(left, { string.rep(" ", fill), nil })
    table.insert(left, { "   ", nil })
    table.insert(left, { rss_text, rss_metric_hl })
    table.insert(left, { "   ", nil })
    table.insert(left, { loaded_text, "MemDashMetric" })
    table.insert(left, { "   ", nil })
    table.insert(left, { parser_text, "MemDashMetricDim" })

    local row_line, row_marks = build_line(left)
    push(row_line, row_marks, { kind = "proc", pid = p.pid, proc = p })

    -- Error band for failed RPC.
    if p.error then
      local err_line = "       ⚠ " .. tostring(p.error)
      push(err_line, { { col = 0, end_col = #err_line, hl = "MemDashError" } },
        { kind = "proc_error", pid = p.pid, proc = p })
    end

    -- Uptime sub-row (dim) — adds context without crowding the main row.
    if p.uptime and p.uptime ~= "?" then
      local up_line = string.format("           started %s", p.uptime)
      push(up_line, { { col = 0, end_col = #up_line, hl = "MemDashUptime" } },
        { kind = "proc_meta", pid = p.pid, proc = p })
    end

    if not shared.dashboard_state.folded[p.pid] and not p.error then
      push("", nil, { kind = "blank" })
      local by_section = { Visible = {}, ["Loaded-Hidden"] = {}, Unloaded = {}, Special = {} }

      for _, b in ipairs(p.buffers or {}) do
        local sec = section_of(b)
        table.insert(by_section[sec], b)
      end

      for _, sec_name in ipairs(SECTION_ORDER) do
        local items = by_section[sec_name]

        if #items > 0 then
          sort_buffers(items, sort_key)
          local count = string.format(" · %d", #items)
          local sec_line, sec_marks = build_line({
            { "        ", nil },
            { sec_name, "MemDashSection" },
            { count, "MemDashSectionCount" },
          })
          push(sec_line, sec_marks, { kind = "section", pid = p.pid, proc = p, section = sec_name })

          for _, b in ipairs(items) do
            local glyph = status_glyph(b)
            local name_max = math.max(18, width - 40)
            local short = b.name:gsub(vim.env.HOME or "~", "~")

            if #short > name_max then
              short = "…" .. short:sub(-name_max + 1)
            end

            local lines_text = string.format("%4dL", b.line_count or 0)
            local idle_text
            if b.idle_min and b.idle_min > 0 then
              idle_text = string.format("%4dm idle", b.idle_min)
            else
              idle_text = "   – idle"
            end
            local est_text = string.format("~%4dK", b.est_kb or 0)

            local left_segs = {
              { "          ", nil },
              { glyph, b.modified and "MemDashBufModified" or "MemDashSep" },
              { "  ", nil },
              { short, b.modified and "MemDashBufModified"
                or (b.loaded and "MemDashBuf" or "MemDashBufDim") },
            }
            local left_text = ""

            for _, seg in ipairs(left_segs) do
              left_text = left_text .. (seg[1] or "")
            end

            local right_text = "   " .. lines_text .. "   " .. idle_text .. "   " .. est_text .. " "
            local pad_n = math.max(1, width - #left_text - #right_text)
            table.insert(left_segs, { string.rep(" ", pad_n), nil })
            table.insert(left_segs, { "   ", nil })
            table.insert(left_segs, { lines_text, "MemDashMetricDim" })
            table.insert(left_segs, { "   ", nil })
            table.insert(left_segs, { idle_text, "MemDashIdle" })
            table.insert(left_segs, { "   ", nil })
            table.insert(left_segs, { est_text, "MemDashEst" })

            local row_l, row_m = build_line(left_segs)
            push(row_l, row_m, { kind = "buffer", pid = p.pid, proc = p, buffer = b })
          end
        end
      end
    end

    if proc_index < #view then
      -- Heavier divider after the current process to mark the boundary
      -- between "this nvim" and the rest; thin dots between siblings.
      local next_proc = view[proc_index + 1]
      local is_boundary = p.is_current and next_proc and not next_proc.is_current
      local glyph = is_boundary and "═" or "·"
      local divider = "  " .. string.rep(glyph, math.max(10, width - 4))
      local hl = is_boundary and "MemDashBoundary" or "MemDashSep"
      push(divider, { { col = 0, end_col = #divider, hl = hl } }, { kind = "divider" })
    else
      push("", nil, { kind = "blank" })
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
    { "u/w", "MemDashHintKey" }, { " unload/wipe · ", "MemDashHint" },
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

  return math.floor(vim.o.columns * 0.85)
end

-- Re-render only (cheap: no RPC, no re-discovery; called by sort/fold).
local function rerender()
  local view = shared.dashboard_state.view or {}
  local lines, marks, row_index = render_view_model(view, inner_width())
  paint(shared.dashboard_state.buf, lines, marks, row_index)
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

  -- Current process is always pinned to the top; remaining processes are
  -- sorted by RSS desc (largest footprint first), ties broken by pid.
  table.sort(view, function(a, b)
    if a.is_current ~= b.is_current then
      return a.is_current and not b.is_current
    end

    local ar, br = a.rss_mb or -1, b.rss_mb or -1

    if ar == br then
      return (a.pid or 0) < (b.pid or 0)
    end

    return ar > br
  end)

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

-- Open a centered help float listing all keybinds; close on any key.
local function open_help_float()
  local rows = {
    { "q", "close dashboard" },
    { "<Esc>", "close dashboard" },
    { "r", "refresh (re-discover + re-render)" },
    { "?", "this help" },
    { "<Tab>", "toggle fold under cursor" },
    { "s", "cycle sort key (size → idle → name)" },
    { "u", "unload buffer under cursor" },
    { "w", "wipe buffer under cursor" },
    { "U", "unload all in section under cursor" },
    { "X", "prune everywhere (confirm)" },
    { "x", "kill remote nvim (y/n confirm)" },
    { "<CR>", "toggle fold (proc row) or jump to buffer" },
  }
  local body = { "", "  Memory Manager — keybindings", "" }

  for _, r in ipairs(rows) do
    table.insert(body, string.format("    %-9s  %s", r[1], r[2]))
  end

  table.insert(body, "")
  table.insert(body, "  any key closes this help")
  table.insert(body, "")
  local width = 56
  local height = #body
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(buf, 0, -1, false, body)
  vim.bo[buf].modifiable = false
  local win = api.nvim_open_win(buf, true, {
    relative = "editor", width = width, height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    border = "rounded", title = " Help ", title_pos = "left",
  })
  -- Highlight key column in the help float.
  local hns = api.nvim_create_namespace("MemDashboardHelp")

  for i = 4, 3 + #rows do
    api.nvim_buf_set_extmark(buf, hns, i - 1, 4, { end_col = 13, hl_group = "MemDashHintKey" })
    api.nvim_buf_set_extmark(buf, hns, i - 1, 15, { end_col = -1, hl_group = "MemDashHint" })
  end

  local function close_help()
    if api.nvim_win_is_valid(win) then api.nvim_win_close(win, true) end
  end

  -- Any key closes the help float (we register the common ones explicitly).
  for _, k in ipairs({ "q", "<Esc>", "<CR>", "?", "<Space>", "h", "j", "k", "l" }) do
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

-- u/w: unload (default) or wipe buffer under cursor (local or remote).
local function action_buffer(verb)
  local row = row_at_cursor()
  if not row or row.kind ~= "buffer" then return end
  local b, proc = row.buffer, row.proc
  local opts = (verb == "unload") and { unload = true } or { force = false }

  if proc.is_current then
    pcall(api.nvim_buf_delete, b.bufnr, opts)
  else
    rpc.remote_buf_delete(proc.socket, b.bufnr, opts)
  end

  refresh()
end

-- U: prune the section under cursor (local pass or remote `:MemPrune 0`).
local function action_section_unload()
  local row = row_at_cursor()
  if not row or row.kind ~= "section" then return end
  local proc = row.proc

  if proc.is_current then
    prune.prune({ force_minutes = 0 })
  else
    rpc.remote_exec(proc.socket, "MemPrune 0")
  end

  refresh()
end

-- X: prune everywhere after a confirm; sends `MemPrune 0` to every process.
local function action_prune_all()
  local choice = fn.confirm("Prune all nvim processes?", "&Yes\n&No", 2)
  if choice ~= 1 then return end
  prune.prune({ force_minutes = 0 })

  for _, p in ipairs(shared.dashboard_state.view or {}) do
    if not p.is_current and p.socket then
      rpc.remote_exec(p.socket, "MemPrune 0")
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
  vim.keymap.set("n", "U", action_section_unload, opts)
  vim.keymap.set("n", "X", action_prune_all, opts)
  vim.keymap.set("n", "x", action_kill_remote, opts)
  vim.keymap.set("n", "<CR>", action_jump, opts)
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
  local width = math.floor(vim.o.columns * 0.85)
  local height = math.floor(vim.o.lines * 0.85)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  local win = api.nvim_open_win(buf, true, {
    relative = "editor", width = width, height = height,
    row = row, col = col,
    border = "rounded",
    title = "  Memory Manager  ", title_pos = "center",
    -- Footer renders inside the bottom border of the float — always pinned
    -- to the very bottom of the window regardless of scroll.
    footer = build_footer(), footer_pos = "center",
  })
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

  api.nvim_create_autocmd("BufWipeout", {
    buffer = buf,
    callback = function()
      shared.dashboard_state.win = nil
      shared.dashboard_state.buf = nil
    end,
  })

  refresh()
end

return M
