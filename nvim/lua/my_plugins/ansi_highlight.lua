-- Highlights ANSI escape code literals (\27[Xm, \x1b[Xm) in source files
-- using colors read from the Ghostty palette, so highlights match what
-- the codes actually produce in the terminal.

local M = {}

-- SGR fg color codes map to Ghostty palette indices (0-7 normal, 8-15 bright)
local SGR_TO_PALETTE = {
  [30] = 0, [31] = 1, [32] = 2, [33] = 3,
  [34] = 4, [35] = 5, [36] = 6, [37] = 7,
  [90] = 8, [91] = 9, [92] = 10, [93] = 11,
  [94] = 12, [95] = 13, [96] = 14, [97] = 15,
}

local ESCAPE_PATTERNS = { "\\27%[([0-9;]+)m", "\\x1b%[([0-9;]+)m" }

local ENABLED_FILETYPES = { sh = true, bash = true, zsh = true }

local NS = vim.api.nvim_create_namespace("ansi_highlight")

-- Cache to avoid re-creating bold variant hl groups across buf scans
local bold_groups_created = {}

-- Reads ~/.config/ghostty/config and returns palette[0..15] = "#rrggbb"
local function parse_ghostty_palette()
  local path = vim.fn.expand("~/.config/ghostty/config")
  local file = io.open(path, "r")
  if not file then return {} end

  local palette = {}
  for line in file:lines() do
    local idx, color = line:match("^palette%s*=%s*(%d+)=#(%x+)")
    if idx then
      palette[tonumber(idx)] = "#" .. color
    end
  end
  file:close()

  return palette
end

-- Creates AnsiSgr_XX hl groups from palette and returns sgr_code → group_name table
local function build_hl_groups()
  local palette = parse_ghostty_palette()
  local groups = {}

  for sgr, palette_idx in pairs(SGR_TO_PALETTE) do
    local color = palette[palette_idx]
    if color then
      local name = "AnsiSgr_" .. sgr
      vim.api.nvim_set_hl(0, name, { fg = color })
      groups[sgr] = name
    end
  end

  -- SGR 2 (dim): italic + bright-black visually signals reduced intensity
  vim.api.nvim_set_hl(0, "AnsiSgr_2", { fg = palette[8] or "#5b6078", italic = true })
  groups[2] = "AnsiSgr_2"

  -- SGR 1 (bold): bold weight on the default fg color
  vim.api.nvim_set_hl(0, "AnsiSgr_1", { fg = palette[7] or "#b8c0e0", bold = true })
  groups[1] = "AnsiSgr_1"

  -- SGR 0 (reset): muted so reset markers are visible but not distracting
  vim.api.nvim_set_hl(0, "AnsiSgr_0", { fg = palette[8] or "#5b6078" })
  groups[0] = "AnsiSgr_0"

  return groups
end

-- Resolves the highlight group for a code sequence like "32" or "1;32" or "2"
local function resolve_group(codes_str, groups)
  local fg_code = nil
  local attr_code = nil
  local is_bold = false

  for code_str in codes_str:gmatch("%d+") do
    local code = tonumber(code_str)
    if code == 1 then
      is_bold = true
    elseif SGR_TO_PALETTE[code] then
      fg_code = code
    elseif code == 0 or code == 2 then
      attr_code = code
    end
  end

  if fg_code then
    if not is_bold then
      return groups[fg_code]
    end
    -- Create a bold variant of the color group on first use
    local bold_name = "AnsiSgr_" .. fg_code .. "_bold"
    if not bold_groups_created[bold_name] then
      local base = vim.api.nvim_get_hl(0, { name = groups[fg_code] })
      vim.api.nvim_set_hl(0, bold_name, { fg = base.fg, bold = true })
      bold_groups_created[bold_name] = true
    end
    return bold_name
  end

  if is_bold then return groups[1] end
  if attr_code then return groups[attr_code] end

  return nil
end

-- Scans all lines in buf for escape literals and applies extmark highlights
local function apply_to_buf(buf, groups)
  vim.api.nvim_buf_clear_namespace(buf, NS, 0, -1)

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

  for lnum, line in ipairs(lines) do
    for _, pattern in ipairs(ESCAPE_PATTERNS) do
      local pos = 1
      while true do
        local match_start, match_end, codes_str = line:find(pattern, pos)
        if not match_start then break end

        local group = resolve_group(codes_str, groups)
        if group then
          vim.api.nvim_buf_set_extmark(buf, NS, lnum - 1, match_start - 1, {
            end_col = match_end,
            hl_group = group,
          })
        end

        pos = match_end + 1
      end
    end
  end
end

function M.setup()
  local groups = build_hl_groups()

  -- Skip non-shell buffers and special buffers (terminal, help, quickfix, etc.)
  local function on_buf_update(args)
    if vim.bo[args.buf].buftype ~= "" then return end
    if not ENABLED_FILETYPES[vim.bo[args.buf].filetype] then return end
    apply_to_buf(args.buf, groups)
  end

  vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost" }, {
    pattern = "*",
    callback = on_buf_update,
  })
end

return M
