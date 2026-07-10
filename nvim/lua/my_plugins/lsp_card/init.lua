-- LSP / treesitter card — lspconfig's original `:LspInfo` window, rebuilt.
--
-- The layout, wording, indentation (one leading space per line, tab-indented
-- info lines), window geometry (80% × 70%), and syntax rules are copied from
-- nvim-lspconfig v0.1.8 `lua/lspconfig/ui/lspinfo.lua`, which upstream has
-- since stubbed out. Setting `filetype=lspinfo` plus the same `syn` commands
-- means any colorscheme themes this exactly as it themed the old window.
--
-- Two additions lspconfig never had, in the same style:
--   * `memory:` on each client — real RSS of the server's child process.
--   * Treesitter and Diagnostics sections for the buffer you came from.
--
-- Opened by `:LspCard` / `sc`.

local api = vim.api
local fn = vim.fn
local collect = require("my_plugins.lsp_card.collect")
local utils = require("my_plugins.my_utils")

local M = {}

local NS = api.nvim_create_namespace("LspCard")

local state = { buf = nil, win = nil, origin_buf = nil }

-- The five groups lspconfig registered in `plugin/lspconfig.lua`. They are
-- `default = true`, so a colorscheme that themes :LspInfo still wins; without
-- them the syntax rules below would match but paint nothing.
local function ensure_highlights()
  local links = {
    LspInfoBorder = "Label",
    LspInfoList = "Function",
    LspInfoTip = "Comment",
    LspInfoTitle = "Title",
    LspInfoFiletype = "Type",
    -- Extra groups this card adds on top of lspconfig's five.
    LspCardHeadline = "Statement",
    LspCardSection = "Title",
    LspCardField = "Identifier",
    LspCardNumber = "Number",
    LspCardPath = "Directory",
    LspCardCmd = "Special",
    LspCardMemory = "Constant",
    LspCardLang = "Type",
    LspCardNone = "Comment",
    LspCardOk = "DiagnosticOk",
    LspCardKey = "Special",
  }

  for group, link in pairs(links) do
    pcall(api.nvim_set_hl, 0, group, { link = link, default = true })
  end
end

-- Prefix every line, exactly like lspconfig's `indent_lines`.
local function indent_lines(lines, offset)
  return vim.tbl_map(function(line)
    return offset .. line
  end, lines)
end

-- One client block: the "Client: name (id: N, bufnr: [1, 4])" headline plus
-- its tab-indented fields. Label column width matches lspconfig's.
local function client_lines(client)
  local buffer_numbers = {}

  for _, bufnr in ipairs(client.buffer_numbers) do
    table.insert(buffer_numbers, tostring(bufnr))
  end

  local lines = {
    "",
    "Client: " .. client.name .. " (id: " .. tostring(client.id)
      .. ", bufnr: [" .. table.concat(buffer_numbers, ", ") .. "])",
  }
  local root_dir = client.root_dir

  if not root_dir or root_dir == "" then
    root_dir = "Running in single file mode."
  end

  local info_lines = {
    "filetypes:       " .. (#client.filetypes > 0
      and table.concat(client.filetypes, ", ") or ""),
    "autostart:       " .. (client.autostart and "true" or "false"),
    "root directory:  " .. root_dir,
    "cmd:             " .. client.cmd,
    "memory:          " .. (client.rss_kb and utils.fmt_kb(client.rss_kb) or "unknown"),
  }

  vim.list_extend(lines, indent_lines(info_lines, "\t"))

  return lines
end

-- Treesitter block for the buffer the card was opened from, plus the totals
-- across every loaded buffer in this nvim.
local function treesitter_lines(snapshot)
  local current

  for _, buffer in ipairs(snapshot.buffers) do
    if buffer.is_current then
      current = buffer
      break
    end
  end

  local ts = current and current.treesitter
  local lines = { "", "Treesitter:" }
  local info_lines

  if ts then
    info_lines = {
      "parser:          " .. ts.lang,
      "injections:      " .. (#ts.injections > 0
        and table.concat(ts.injections, ", ") or "none"),
      "buffer memory:   ~" .. utils.fmt_kb(ts.est_kb) .. " (estimate)",
    }
  else
    info_lines = { "parser:          no active parser in this buffer" }
  end

  table.insert(info_lines, "active parsers:  " .. tostring(snapshot.parser_count))
  table.insert(info_lines, "languages:       " .. (#snapshot.languages > 0
    and table.concat(snapshot.languages, ", ") or "none"))
  table.insert(info_lines, "total memory:    ~" .. utils.fmt_kb(snapshot.parser_est_kb)
    .. " (estimate)")
  vim.list_extend(lines, indent_lines(info_lines, "\t"))

  return lines
end

-- Diagnostics for the origin buffer, with the whole-session totals beside it.
local function diagnostic_lines(snapshot)
  local buffer_counts = snapshot.buffer_diagnostics
  local total_counts = snapshot.diagnostics

  local function pair(buffer_count, total_count)
    return string.format("%d  (%d in all buffers)", buffer_count, total_count)
  end

  local lines = { "", "Diagnostics:" }
  local info_lines = {
    "errors:          " .. pair(buffer_counts[1], total_counts[1]),
    "warnings:        " .. pair(buffer_counts[2], total_counts[2]),
    "info:            " .. pair(buffer_counts[3], total_counts[3]),
    "hints:           " .. pair(buffer_counts[4], total_counts[4]),
  }
  vim.list_extend(lines, indent_lines(info_lines, "\t"))

  return lines
end

-- The whole buffer, assembled in lspconfig's original order.
local function build_lines(snapshot)
  local attached, other_active = {}, {}

  for _, client in ipairs(snapshot.clients) do
    table.insert(client.attached and attached or other_active, client)
  end

  local lines = {
    "Press q or <Esc> to close this window. Press r to refresh.",
    "",
    "Language client log: " .. snapshot.log_path,
    "Detected filetype:   " .. snapshot.filetype,
    "",
    tostring(#attached) .. " client(s) attached to this buffer: ",
  }

  for _, client in ipairs(attached) do
    vim.list_extend(lines, client_lines(client))
  end

  if #other_active > 0 then
    vim.list_extend(lines, {
      "",
      tostring(#other_active) .. " active client(s) not attached to this buffer: ",
    })

    for _, client in ipairs(other_active) do
      vim.list_extend(lines, client_lines(client))
    end
  end

  vim.list_extend(lines, treesitter_lines(snapshot))
  vim.list_extend(lines, diagnostic_lines(snapshot))

  if #snapshot.configured_servers > 0 then
    vim.list_extend(lines, {
      "",
      "Configured servers list: " .. table.concat(snapshot.configured_servers, ", "),
    })
  end

  return indent_lines(lines, " ")
end

-- lspconfig's syntax rules, verbatim: client/config names get LspInfoTitle,
-- the filetype list gets LspInfoFiletype, the server list gets LspInfoList,
-- and true/false render as String/Error.
local function apply_syntax()
  -- lspconfig's original rules first; the card's own rules are defined after
  -- so they take priority where the two overlap.
  vim.cmd([[
    syn keyword String true
    syn keyword Error false
    syn match LspInfoFiletype /\k\+/ contained
    syn match LspInfoList /\S\+/ contained
  ]])

  -- Section headlines, field labels, and one group per value type, so every
  -- column of the card carries meaning: paths are directories, commands are
  -- special, memory is a constant, languages are types, counts are numbers,
  -- and diagnostic values take their severity's color (green at zero).
  --
  -- Value rules use a lookbehind (`\@<=`) rather than `\zs`: a `\zs` pattern
  -- still *matches* from column 1, which collides with the label rule (Vim
  -- lets only one syntax item own a region, so the label rule would win and
  -- the value would end up unhighlighted). A lookbehind starts the match at
  -- the value itself, after the label rule's region has ended.
  vim.cmd([[
    syn match LspCardHeadline /^\s*\d\+ \%(client(s) attached\|active client(s) not attached\).*$/ contains=LspCardNumber
    syn match LspCardSection /^\s*\%(Treesitter\|Diagnostics\):/
    syn match LspCardField /\%(^\s*\t\)\@<=[a-z][a-z ]*:/
    syn match LspCardNumber /\<\d\+\>/ contained

    syn match LspCardClientLine /^\s*Client: .*$/ contains=LspInfoTitle,LspCardClientMeta
    syn match LspInfoTitle /\%(Client:\s*\)\@<=\S\+/ contained
    syn match LspCardClientMeta /(id: .*\])/ contained contains=LspCardNumber

    syn match LspInfoFiletypeList /\%(filetypes\?:\s*\)\@<=\S.*$/ contains=LspInfoFiletype
    syn match LspInfoListList /\%(Configured servers list:\s*\)\@<=\S.*$/ contains=LspInfoList

    syn match LspCardPath /\%(Language client log:\s*\)\@<=\S.*$/
    syn match LspCardPath /\%(root directory:\s*\)\@<=\S.*$/
    syn match LspCardCmd /\%(cmd:\s*\)\@<=\S.*$/
    syn match LspCardMemory /\%(memory:\s*\)\@<=\S.*$/
    syn match LspCardLang /\%(\%(parser\|injections\|languages\):\s*\)\@<=\S.*$/
    syn match LspCardNumber /\%(active parsers:\s*\)\@<=\d\+/

    syn match LspCardOk /\%(\%(errors\|warnings\|info\|hints\):\s*\)\@<=0\>.*$/
    syn match DiagnosticError /\%(errors:\s*\)\@<=[1-9]\d*.*$/
    syn match DiagnosticWarn /\%(warnings:\s*\)\@<=[1-9]\d*.*$/
    syn match DiagnosticInfo /\%(info:\s*\)\@<=[1-9]\d*.*$/
    syn match DiagnosticHint /\%(hints:\s*\)\@<=[1-9]\d*.*$/

    syn match LspCardNone /\<\%(none\|unknown\)\>/
  ]])

  -- Window-local matches: the keys in the tip line pop, and anything the card
  -- reports as missing reads as an error (as in the original).
  fn.matchadd("LspCardKey", "\\%1lq\\|\\%1l<Esc>\\|\\%1l\\<r\\>")
  fn.matchadd("Error",
    "cmd not defined\\|Running in single file mode\\.\\|no active parser in this buffer")
end

-- The tip line is highlighted as a whole; syntax rules don't cover it.
local function highlight_tip()
  pcall(api.nvim_buf_set_extmark, state.buf, NS, 0, 0, {
    end_row = 1, hl_group = "LspInfoTip", hl_eol = true,
  })
end

local function close_card()
  if state.win and api.nvim_win_is_valid(state.win) then
    api.nvim_win_close(state.win, true)
  end
end

local function refresh()
  local snapshot = collect.snapshot({
    current_buf = state.origin_buf,
    exclude_buf = state.buf,
  })

  vim.bo[state.buf].modifiable = true
  api.nvim_buf_clear_namespace(state.buf, NS, 0, -1)
  api.nvim_buf_set_lines(state.buf, 0, -1, true, build_lines(snapshot))
  vim.bo[state.buf].modifiable = false
  highlight_tip()
end

-- 80% × 70% of the editor, centered — lspconfig's percentage_range_window.
local function geometry()
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.7)

  return {
    relative = "editor", width = width, height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    border = "rounded",
  }
end

-- Open the card (idempotent: focuses + refreshes when already open).
function M.open()
  ensure_highlights()

  if state.win and api.nvim_win_is_valid(state.win) then
    api.nvim_set_current_win(state.win)
    refresh()
    return
  end

  state.origin_buf = api.nvim_get_current_buf()
  local buf = api.nvim_create_buf(false, true)
  state.buf = buf
  local win = api.nvim_open_win(buf, true, geometry())
  state.win = win

  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "lspinfo"
  -- Long cmd / root-directory lines wrap under their label instead of being
  -- cut off, exactly like the original window.
  vim.wo[win].wrap = true
  vim.wo[win].breakindent = true
  vim.wo[win].breakindentopt = "shift:25"
  vim.wo[win].showbreak = "NONE"
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].cursorline = false
  vim.wo[win].winhighlight = "FloatBorder:LspInfoBorder"

  refresh()
  apply_syntax()

  local opts = { buffer = buf, nowait = true, silent = true }
  vim.keymap.set("n", "q", close_card, opts)
  vim.keymap.set("n", "<Esc>", close_card, opts)
  vim.keymap.set("n", "r", refresh, opts)

  api.nvim_create_autocmd({ "BufDelete", "BufHidden" }, {
    once = true,
    buffer = buf,
    callback = function()
      state.win = nil
      state.buf = nil
    end,
  })
end

return M
