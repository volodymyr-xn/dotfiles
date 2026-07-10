-- Shortcuts float: every keymap this nvim has, grouped and searchable.
--
-- Opened by `:Shortcuts` / `s?`. `s` cycles the grouping (defining file →
-- key prefix → mode), `/` filters, `<CR>` jumps to where the map is defined.

local api = vim.api
local fn = vim.fn
local collect = require("my_plugins.shortcuts.collect")

local M = {}

local NS = api.nvim_create_namespace("Shortcuts")
local INDENT = "   "
local GROUPING_ORDER = { file = "prefix", prefix = "mode", mode = "file" }
local GROUPING_LABEL = {
  file = "defining file",
  prefix = "key prefix",
  mode = "mode",
}

local state = {
  buf = nil, win = nil, row_index = {}, origin_buf = nil,
  grouping = "file", filter = "",
}

local COLUMNS = {
  { title = "KEYS", width = 22 },
  { title = "MODE", width = 8 },
  { title = "DESCRIPTION", flex = 6 },
  { title = "SOURCE", flex = 4 },
}

-- Default highlight links so minimal colorschemes still render readably.
local function ensure_highlights()
  local links = {
    ShortcutsBorder = "FloatBorder",
    ShortcutsSection = "Statement",
    ShortcutsLabel = "Comment",
    ShortcutsKey = "Special",
    ShortcutsMode = "Number",
    ShortcutsDesc = "Normal",
    ShortcutsDim = "Comment",
    ShortcutsBufferLocal = "DiagnosticOk",
    ShortcutsMetric = "Special",
    ShortcutsHintKey = "Special",
    ShortcutsHintText = "Comment",
  }

  for group, link in pairs(links) do
    pcall(api.nvim_set_hl, 0, group, { link = link, default = true })
  end
end

-- ============================================================================
-- Render helpers
-- ============================================================================

local function build_line(segments)
  local parts = {}
  local marks = {}
  local col = 0

  for _, segment in ipairs(segments) do
    local text = segment[1] or ""
    parts[#parts + 1] = text

    if segment[2] and text ~= "" then
      table.insert(marks, { col = col, end_col = col + #text, hl = segment[2] })
    end

    col = col + #text
  end

  return table.concat(parts), marks
end

local function truncate(text, max_width)
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

-- Keep the tail of a path visible — the filename matters more than the root.
local function shorten_path(path, max_width)
  if not path or path == "" then
    return "—"
  end

  local home = vim.env.HOME or ""

  if home ~= "" and path:sub(1, #home) == home then
    path = "~" .. path:sub(#home + 1)
  end

  if #path > max_width then
    path = "…" .. path:sub(-max_width + 1)
  end

  return path
end

local function resolve_widths(width)
  local inner = width - #INDENT - (#COLUMNS + 1)
  local fixed, flex_total = 0, 0

  for _, column in ipairs(COLUMNS) do
    if column.width then
      fixed = fixed + column.width
    else
      flex_total = flex_total + column.flex
    end
  end

  local flex_space = math.max(#COLUMNS * 8, inner - fixed)
  local widths = {}
  local assigned = 0
  local last_flex

  for index, column in ipairs(COLUMNS) do
    if column.width then
      widths[index] = column.width
    else
      widths[index] = math.max(10, math.floor(flex_space * column.flex / flex_total))
      assigned = assigned + widths[index]
      last_flex = index
    end
  end

  if last_flex then
    widths[last_flex] = widths[last_flex] + (flex_space - assigned)
  end

  return widths
end

local function build_rule(widths, left, cross, right)
  local parts = { INDENT, left }

  for index, width in ipairs(widths) do
    parts[#parts + 1] = string.rep("─", width)
    parts[#parts + 1] = (index < #widths) and cross or right
  end

  local line = table.concat(parts)

  return line, { { col = #INDENT, end_col = #line, hl = "ShortcutsBorder" } }
end

local function build_row(widths, cells)
  local parts = { INDENT }
  local marks = {}
  local col = #INDENT

  for index, width in ipairs(widths) do
    parts[#parts + 1] = "│"
    table.insert(marks, { col = col, end_col = col + #"│", hl = "ShortcutsBorder" })
    col = col + #"│"

    local cell = cells[index] or {}
    local text = truncate(cell[1] or "", width - 2)
    local trail = width - 1 - fn.strdisplaywidth(text)

    parts[#parts + 1] = " "
    col = col + 1
    parts[#parts + 1] = text

    if text ~= "" and cell[2] then
      table.insert(marks, { col = col, end_col = col + #text, hl = cell[2] })
    end

    col = col + #text
    parts[#parts + 1] = string.rep(" ", math.max(0, trail))
    col = col + math.max(0, trail)
  end

  parts[#parts + 1] = "│"
  table.insert(marks, { col = col, end_col = col + #"│", hl = "ShortcutsBorder" })

  return table.concat(parts), marks
end

-- A full-width row spanning every column, used for the group headers so a
-- group reads as a band inside the table rather than a separate list.
local function build_span_row(widths, segments)
  local span = #widths - 1

  for _, width in ipairs(widths) do
    span = span + width
  end

  local content_width = span - 2
  local used = 0

  for _, segment in ipairs(segments) do
    used = used + fn.strdisplaywidth(segment[1])
  end

  local all = { { INDENT, nil }, { "│ ", "ShortcutsBorder" } }
  vim.list_extend(all, segments)
  table.insert(all, { string.rep(" ", math.max(1, content_width - used)), nil })
  table.insert(all, { " │", "ShortcutsBorder" })

  return build_line(all)
end

-- Case-insensitive substring match across the fields the user can see.
local function matches_filter(mapping, filter)
  if filter == "" then
    return true
  end

  local needle = filter:lower()

  return (mapping.lhs:lower():find(needle, 1, true) ~= nil)
    or (mapping.description:lower():find(needle, 1, true) ~= nil)
    or (mapping.group_file:lower():find(needle, 1, true) ~= nil)
end

-- ============================================================================
-- Render
-- ============================================================================

local function render(width)
  local groups, total = collect.grouped(state.origin_buf, state.grouping)
  local widths = resolve_widths(width)
  local lines, marks, row_index = {}, {}, {}

  local function push(line, line_marks, kind)
    table.insert(lines, line)
    local index = #lines - 1

    for _, mark in ipairs(line_marks or {}) do
      table.insert(marks, {
        line = index, col = mark.col, end_col = mark.end_col, hl = mark.hl,
      })
    end

    row_index[#lines] = kind or { kind = "blank" }
  end

  push("", nil, { kind = "blank" })

  local shown = 0

  for _, group in ipairs(groups) do
    for _, mapping in ipairs(group.items) do
      if matches_filter(mapping, state.filter) then
        shown = shown + 1
      end
    end
  end

  local stats = {
    { INDENT, nil },
    { "Grouped by", "ShortcutsLabel" },
    { "  ", nil },
    { GROUPING_LABEL[state.grouping], "ShortcutsMetric" },
    { "   ·   ", "ShortcutsDim" },
    { "Mappings", "ShortcutsLabel" },
    { "  ", nil },
    { string.format("%d of %d", shown, total), "ShortcutsMetric" },
  }

  if state.filter ~= "" then
    table.insert(stats, { "   ·   ", "ShortcutsDim" })
    table.insert(stats, { "Filter", "ShortcutsLabel" })
    table.insert(stats, { "  ", nil })
    table.insert(stats, { state.filter, "ShortcutsKey" })
  end

  push(build_line(stats))
  push("", nil, { kind = "blank" })
  push(build_rule(widths, "╭", "┬", "╮"))

  local header_cells = {}

  for index, column in ipairs(COLUMNS) do
    header_cells[index] = { column.title, "ShortcutsLabel" }
  end

  push(build_row(widths, header_cells))

  for _, group in ipairs(groups) do
    local items = vim.tbl_filter(function(mapping)
      return matches_filter(mapping, state.filter)
    end, group.items)

    if #items > 0 then
      push(build_rule(widths, "├", "┴", "┤"))
      push(build_span_row(widths, {
        { group.title, "ShortcutsSection" },
        { string.format("  · %d", #items), "ShortcutsDim" },
      }), { kind = "group" })
      push(build_rule(widths, "├", "┬", "┤"))

      for _, mapping in ipairs(items) do
        local source = mapping.source
          and shorten_path(mapping.source:match("([^/]+/[^/]+)$") or mapping.source, 40)
          or "—"
        local mode_text = mapping.mode

        if mapping.buffer_local then
          mode_text = mode_text .. " buf"
        end

        local row_line, row_marks = build_row(widths, {
          { mapping.lhs, "ShortcutsKey" },
          { mode_text, mapping.buffer_local and "ShortcutsBufferLocal" or "ShortcutsMode" },
          { mapping.description, "ShortcutsDesc" },
          { source, "ShortcutsDim" },
        })
        push(row_line, row_marks, { kind = "mapping", mapping = mapping })
      end
    end
  end

  push(build_rule(widths, "╰", "┴", "╯"))
  push("", nil, { kind = "blank" })

  return lines, marks, row_index
end

-- ============================================================================
-- Window
-- ============================================================================

local function paint(lines, marks, row_index)
  local buf = state.buf
  vim.bo[buf].modifiable = true
  api.nvim_buf_clear_namespace(buf, NS, 0, -1)
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  for _, mark in ipairs(marks) do
    pcall(api.nvim_buf_set_extmark, buf, NS, mark.line, mark.col,
      { end_col = mark.end_col, hl_group = mark.hl })
  end

  vim.bo[buf].modifiable = false
  state.row_index = row_index
end

local function inner_width()
  if state.win and api.nvim_win_is_valid(state.win) then
    return api.nvim_win_get_width(state.win)
  end

  return math.max(40, vim.o.columns - 2)
end

local function rerender()
  local lines, marks, row_index = render(inner_width())
  paint(lines, marks, row_index)
end

local function close_shortcuts()
  if state.win and api.nvim_win_is_valid(state.win) then
    api.nvim_win_close(state.win, true)
  end
end

-- `s` — cycle the grouping: defining file → key prefix → mode.
local function cycle_grouping()
  state.grouping = GROUPING_ORDER[state.grouping] or "file"
  rerender()
end

-- `/` — filter by keys, description, or group; empty input clears it.
local function prompt_filter()
  local ok, input = pcall(fn.input, "Filter shortcuts: ", state.filter)

  if not ok then
    return
  end

  state.filter = input or ""
  rerender()
end

local function clear_filter()
  if state.filter == "" then
    close_shortcuts()
    return
  end

  state.filter = ""
  rerender()
end

-- <CR> — open the file that defines the mapping under the cursor, at its line.
local function jump_to_definition()
  local row = state.row_index[api.nvim_win_get_cursor(state.win)[1]]

  if not row or row.kind ~= "mapping" then
    return
  end

  local mapping = row.mapping

  if not mapping.source then
    vim.notify("[shortcuts] no source file for " .. mapping.lhs, vim.log.levels.INFO)
    return
  end

  close_shortcuts()
  vim.cmd("edit " .. fn.fnameescape(mapping.source))

  if mapping.source_line and mapping.source_line > 0 then
    pcall(api.nvim_win_set_cursor, 0, { mapping.source_line, 0 })
  end
end

local function footer()
  return {
    { " ", "FloatFooter" },
    { "q", "ShortcutsHintKey" }, { " close · ", "ShortcutsHintText" },
    { "s", "ShortcutsHintKey" }, { " grouping · ", "ShortcutsHintText" },
    { "/", "ShortcutsHintKey" }, { " filter · ", "ShortcutsHintText" },
    { "<Esc>", "ShortcutsHintKey" }, { " clear filter · ", "ShortcutsHintText" },
    { "r", "ShortcutsHintKey" }, { " refresh · ", "ShortcutsHintText" },
    { "↵", "ShortcutsHintKey" }, { " jump to definition ", "ShortcutsHintText" },
  }
end

local function geometry()
  local width = math.max(40, vim.o.columns - 2)
  local height = math.floor(vim.o.lines * 0.85)

  return {
    relative = "editor", width = width, height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
  }
end

local function resize_to_editor()
  if not state.win or not api.nvim_win_is_valid(state.win) then
    return
  end

  api.nvim_win_set_config(state.win, geometry())
  rerender()
end

-- Open the float (idempotent: focuses + re-renders when already open).
function M.open()
  ensure_highlights()

  if state.win and api.nvim_win_is_valid(state.win) then
    api.nvim_set_current_win(state.win)
    rerender()
    return
  end

  state.origin_buf = api.nvim_get_current_buf()
  state.filter = ""
  local buf = api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "Shortcuts"

  local config = geometry()
  config.border = "rounded"
  config.title = "  Shortcuts  "
  config.title_pos = "center"
  config.footer = footer()
  config.footer_pos = "center"

  local win = api.nvim_open_win(buf, true, config)
  vim.wo[win].cursorline = true
  vim.wo[win].wrap = false
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].fillchars = "eob: "
  state.buf = buf
  state.win = win

  local opts = { buffer = buf, nowait = true, silent = true }
  vim.keymap.set("n", "q", close_shortcuts, opts)
  vim.keymap.set("n", "<Esc>", clear_filter, opts)
  vim.keymap.set("n", "s", cycle_grouping, opts)
  vim.keymap.set("n", "/", prompt_filter, opts)
  vim.keymap.set("n", "r", rerender, opts)
  vim.keymap.set("n", "<CR>", jump_to_definition, opts)

  local group = api.nvim_create_augroup("ShortcutsResize", { clear = true })

  api.nvim_create_autocmd("VimResized", {
    group = group,
    callback = resize_to_editor,
  })

  api.nvim_create_autocmd("BufWipeout", {
    buffer = buf,
    callback = function()
      api.nvim_del_augroup_by_id(group)
      state.win = nil
      state.buf = nil
    end,
  })

  rerender()
end

return M
