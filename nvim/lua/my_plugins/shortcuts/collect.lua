-- Keymap collection + grouping for the shortcuts float.
--
-- Every mapping is read live from nvim (`nvim_get_keymap` + the origin
-- buffer's local maps), so the list can never drift from what is actually
-- bound. The defining file comes from `debug.getinfo` on the Lua callback,
-- falling back to the script id that vimscript-registered maps carry.

local api = vim.api
local fn = vim.fn

local M = {}

local MODES = { "n", "v", "x", "o", "i", "t", "c", "s" }

local MODE_NAMES = {
  n = "NORMAL", v = "VISUAL", x = "VISUAL BLOCK", o = "OPERATOR",
  i = "INSERT", t = "TERMINAL", c = "COMMAND", s = "SELECT",
}

-- Prefixes worth grouping by; the longest match wins so `<leader>g` beats
-- `<leader>`. Anything else falls into a single-key group of its own.
local PREFIXES = { "<Leader>", "<leader>", " ", "<C-w>", "g", "z", "[", "]", "s" }

-- Where a mapping was defined. Lua callbacks carry their source file in
-- debug info; vimscript maps only carry a script id (sid), which
-- getscriptinfo() resolves to a path.
local function source_of(mapping)
  if mapping.callback then
    local info = debug.getinfo(mapping.callback, "S")

    if info and info.source and info.source:sub(1, 1) == "@" then
      return info.source:sub(2), info.linedefined
    end
  end

  if mapping.sid and mapping.sid > 0 then
    local ok, scripts = pcall(fn.getscriptinfo, { sid = mapping.sid })

    if ok and scripts and scripts[1] then
      return scripts[1].name, mapping.lnum
    end
  end

  return nil, nil
end

-- Turn a source path into a short group label:
--   …/nvim/lua/keymappings/finders.lua      → "FINDERS"
--   …/nvim/lua/plugin_settings/fugitive.lua → "PLUGIN SETTINGS: FUGITIVE"
--   …/lazy/which-key.nvim/lua/…             → "PLUGIN: WHICH-KEY.NVIM"
--   nil                                     → "OTHER"
local function group_from_source(path)
  if not path or path == "" then
    return "OTHER"
  end

  local plugin = path:match("/lazy/([^/]+)/")

  if plugin then
    return "PLUGIN: " .. plugin:upper()
  end

  local keymap_file = path:match("/keymappings/([^/]+)%.lua$")

  if keymap_file then
    return keymap_file:upper()
  end

  local setting_file = path:match("/plugin_settings/([^/]+)%.lua$")

  if setting_file then
    return "SETTINGS: " .. setting_file:upper()
  end

  local my_plugin = path:match("/my_plugins/([^/]+)")

  if my_plugin then
    return "MY PLUGIN: " .. my_plugin:upper()
  end

  local runtime = path:match("/nvim/runtime/(.+)$") or path:match("/share/nvim/(.+)$")

  if runtime then
    return "NEOVIM BUILT-IN"
  end

  return "OTHER"
end

-- Longest matching prefix of an lhs, normalized so <Space> and <leader>
-- collapse into one group. Keys that begin no known prefix (`!`, `"`, `<C-h>`,
-- <Plug> maps …) share one bucket rather than each spawning a group of one.
local function prefix_of(lhs)
  local normalized = lhs:gsub("^ ", "<leader>"):gsub("^<Space>", "<leader>")
  local best = nil

  for _, prefix in ipairs(PREFIXES) do
    if #prefix > 1 and normalized:sub(1, #prefix) == prefix
      and (not best or #prefix > #best) then
      best = prefix
    end
  end

  -- Single-char prefixes only count when something follows them; a bare `g`
  -- is its own mapping, not the `g…` group.
  if not best then
    for _, prefix in ipairs(PREFIXES) do
      if #prefix == 1 and #normalized > 1 and normalized:sub(1, 1) == prefix then
        best = prefix
      end
    end
  end

  if not best then
    return "UNGROUPED KEYS"
  end

  return (best:gsub("^<Leader>$", "<leader>"))
end

-- What a mapping does, in one line: prefer the desc, fall back to the rhs,
-- and label bare Lua callbacks that carry neither.
local function describe(mapping)
  if mapping.desc and mapping.desc ~= "" then
    return mapping.desc
  end

  if mapping.rhs and mapping.rhs ~= "" then
    return (mapping.rhs:gsub("%s+", " "))
  end

  if mapping.callback then
    return "lua function"
  end

  return "—"
end

-- Every mapping in every mode, global plus the origin buffer's local maps.
local function collect_mappings(origin_buf)
  local seen = {}
  local mappings = {}

  local function add(mapping, mode, is_buffer_local)
    -- `lhs` is already human-readable ("<C-\>"); running keytrans on it would
    -- re-escape the angle brackets ("<lt>C-Bslash>"). Only the raw byte form
    -- needs translating.
    local lhs = mapping.lhsraw and fn.keytrans(mapping.lhsraw) or (mapping.lhs or "")
    local key = mode .. "\0" .. lhs .. "\0" .. tostring(is_buffer_local)

    if lhs == "" or seen[key] then
      return
    end

    seen[key] = true
    local source, line = source_of(mapping)

    table.insert(mappings, {
      lhs = lhs,
      mode = mode,
      mode_name = MODE_NAMES[mode] or mode:upper(),
      description = describe(mapping),
      buffer_local = is_buffer_local,
      source = source,
      source_line = line,
      group_file = group_from_source(source),
      group_prefix = prefix_of(lhs),
    })
  end

  for _, mode in ipairs(MODES) do
    for _, mapping in ipairs(api.nvim_get_keymap(mode)) do
      add(mapping, mode, false)
    end

    if origin_buf and api.nvim_buf_is_valid(origin_buf) then
      for _, mapping in ipairs(api.nvim_buf_get_keymap(origin_buf, mode)) do
        add(mapping, mode, true)
      end
    end
  end

  return mappings
end

-- Bucket mappings under the key that the current grouping mode selects, and
-- return `{ { title = …, items = { … } }, … }` sorted by title, with the
-- keymappings/ groups first (they are the ones you actually wrote).
function M.grouped(origin_buf, grouping)
  local mappings = collect_mappings(origin_buf)
  local buckets = {}

  for _, mapping in ipairs(mappings) do
    local title

    if grouping == "prefix" then
      title = mapping.group_prefix
    elseif grouping == "mode" then
      title = mapping.mode_name
    else
      title = mapping.group_file
    end

    buckets[title] = buckets[title] or {}
    table.insert(buckets[title], mapping)
  end

  local groups = {}

  for title, items in pairs(buckets) do
    table.sort(items, function(a, b)
      if a.lhs ~= b.lhs then
        return a.lhs < b.lhs
      end

      return a.mode < b.mode
    end)

    -- Own keymaps first, third-party plugins last, "OTHER" at the bottom.
    local rank = 1

    if title:match("^SETTINGS:") or title:match("^MY PLUGIN:") then
      rank = 2
    elseif title:match("^PLUGIN:") or title == "NEOVIM BUILT-IN" then
      rank = 3
    elseif title == "OTHER" or title == "UNGROUPED KEYS" then
      rank = 4
    end

    table.insert(groups, { title = title, items = items, rank = rank })
  end

  table.sort(groups, function(a, b)
    if a.rank ~= b.rank then
      return a.rank < b.rank
    end

    return a.title < b.title
  end)

  return groups, #mappings
end

return M
