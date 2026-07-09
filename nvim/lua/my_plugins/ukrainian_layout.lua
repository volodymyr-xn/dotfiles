-- Make Neovim usable with the Ukrainian (ЙЦУКЕН) keyboard layout active at
-- the OS level, so Normal/Visual/Operator-pending commands and custom
-- keymaps fire without switching back to the English layout first.
--
-- Two mechanisms are needed because they cover different things:
--   1. `langmap` translates Cyrillic keys to their Latin meaning for
--      BUILT-IN commands/motions (hjkl, w, b, e, d, c, y, x, p, f, %, ...).
--      It is applied AFTER mapping resolution, so it never reaches custom
--      keymaps whose lhs are Latin letters.
--   2. Keymap mirroring: for every existing custom mapping we register a
--      twin whose lhs is the Cyrillic equivalent of the Latin lhs, pointing
--      at the same rhs/callback. This makes user + plugin shortcuts work
--      under the Ukrainian layout too.
--
-- In the non-typing modes (n/o/x/s) any custom mapping is mirrored. In the
-- typing modes (Insert, Command-line) only modifier-chord mappings
-- (<C-..>, <M-..>, <D-..>, <A-..>) are mirrored: a plain-letter twin there
-- would hijack real Ukrainian typing (e.g. a `jk`->Esc twin firing on the
-- word "ол"), while a chord twin can never collide with typed text.

local M = {}

-- Physical QWERTY key -> Ukrainian glyph it produces (standard ЙЦУКЕН).
-- Used both to build `langmap` (Cyrillic -> Latin) and to translate a
-- Latin mapping lhs into its Cyrillic twin.
local latin_to_ua = {
  q = "й", w = "ц", e = "у", r = "к", t = "е", y = "н", u = "г", i = "ш",
  o = "щ", p = "з", ["["] = "х", ["]"] = "ї",
  a = "ф", s = "і", d = "в", f = "а", g = "п", h = "р", j = "о", k = "л",
  l = "д", [";"] = "ж", ["'"] = "є",
  z = "я", x = "ч", c = "с", v = "м", b = "и", n = "т", m = "ь",
  [","] = "б", ["."] = "ю",

  Q = "Й", W = "Ц", E = "У", R = "К", T = "Е", Y = "Н", U = "Г", I = "Ш",
  O = "Щ", P = "З", ["{"] = "Х", ["}"] = "Ї",
  A = "Ф", S = "І", D = "В", F = "А", G = "П", H = "Р", J = "О", K = "Л",
  L = "Д", [":"] = "Ж", ['"'] = "Є",
  Z = "Я", X = "Ч", C = "С", V = "М", B = "И", N = "Т", M = "Ь",
  ["<"] = "Б", [">"] = "Ю",
}

-- Characters that must be backslash-escaped inside the `langmap` value.
local langmap_specials = { [";"] = true, [","] = true, ['"'] = true, ["|"] = true, ["\\"] = true }

-- Escape a single char for safe inclusion in the `langmap` option string.
local function escape_for_langmap(char)
  if langmap_specials[char] then
    return "\\" .. char
  end

  return char
end

-- Build the `langmap` value as "<cyrillic><latin>" pairs joined by commas.
local function build_langmap()
  local pairs_list = {}

  for latin, ua in pairs(latin_to_ua) do
    pairs_list[#pairs_list + 1] = ua .. escape_for_langmap(latin)
  end

  return table.concat(pairs_list, ",")
end

-- Modes to mirror. Insert (i) and Command-line (c) are typing modes: there
-- only modifier-chord mappings are mirrored (see typing_modes below).
local mirror_modes = { "n", "o", "x", "s", "i", "c" }

-- Modes where typed characters become text, so plain-letter twins are unsafe.
local typing_modes = { i = true, c = true }

-- Alt/Option/Cmd modifiers. The base character of these chords can come
-- through as the Cyrillic glyph under a Ukrainian layout, so the letter is
-- translated. Ctrl is deliberately excluded: terminals derive Ctrl-combos
-- from the ASCII/physical key regardless of layout, so <C-..> already fires
-- and <C-cyrillic> is not even a representable keycode.
local translated_modifiers = { m = true, a = true, d = true }

-- Remembers already-created twins so repeated syncs stay idempotent and
-- cheap. Key: "<bufnr><mode><cyrillic-lhs>".
M._seen = {}

-- Translate one <...> token. For an Alt/Cmd chord ending in a single letter
-- (<M-a> -> <M-ф>) the letter is translated. Ctrl chords and named keys
-- (<CR>, <Tab>, <Leader>, <F5>, <Space>, <Plug>..) are left intact.
-- Returns the rebuilt token and whether it is a modifier chord at all
-- (Ctrl included) -- a modifier prefix means the sequence cannot be produced
-- by ordinary typing, which gates mirroring in typing modes.
local function translate_token(inner)
  local segments = vim.split(inner, "-", { plain = true })

  if #segments < 2 then
    return "<" .. inner .. ">", false
  end

  local has_ctrl = false
  local has_translated_modifier = false

  for index = 1, #segments - 1 do
    local modifier = segments[index]:lower()

    if modifier == "c" then
      has_ctrl = true
    elseif translated_modifiers[modifier] then
      has_translated_modifier = true
    end
  end

  local last = segments[#segments]

  if has_translated_modifier and not has_ctrl and #last == 1 and latin_to_ua[last] then
    segments[#segments] = latin_to_ua[last]
  end

  return "<" .. table.concat(segments, "-") .. ">", has_ctrl or has_translated_modifier
end

-- Translate a Latin mapping lhs into its Cyrillic twin. Returns the new lhs
-- and whether it STARTS with a modifier chord -- such a mapping cannot be
-- triggered by plain typing, so it is safe to mirror even in typing modes.
local function translate_lhs(lhs)
  local out = {}
  local i = 1
  local length = #lhs
  local starts_with_chord = false
  local first_seen = false

  while i <= length do
    local char = lhs:sub(i, i)
    local is_chord = false

    if char == "<" then
      local close = lhs:find(">", i + 1, true)

      if close then
        local token, chord = translate_token(lhs:sub(i + 1, close - 1))
        out[#out + 1] = token
        is_chord = chord
        i = close + 1
      else
        out[#out + 1] = char
        i = i + 1
      end
    else
      out[#out + 1] = latin_to_ua[char] or char
      i = i + 1
    end

    if not first_seen then
      starts_with_chord = is_chord
      first_seen = true
    end
  end

  return table.concat(out), starts_with_chord
end

-- Internal plugin plumbing (<Plug>.., <SNR>.., <SID>..) is never typed by
-- the user, so it must not be mirrored -- translating its trailing letters
-- would only create dead twins.
local function is_internal_lhs(lhs)
  local lower = lhs:lower()

  return vim.startswith(lower, "<plug>")
    or vim.startswith(lower, "<snr>")
    or vim.startswith(lower, "<sid>")
end

-- Register Cyrillic twins for every mapping in `mode`. When `bufnr` is
-- given, mirrors that buffer's local maps (ftplugin/LSP); otherwise globals.
local function mirror_mode(mode, bufnr)
  local maps = bufnr and vim.api.nvim_buf_get_keymap(bufnr, mode)
    or vim.api.nvim_get_keymap(mode)

  local skip_plain = typing_modes[mode]

  for _, map in ipairs(maps) do
    local new_lhs, starts_with_chord = translate_lhs(map.lhs)

    if not is_internal_lhs(map.lhs)
      and new_lhs ~= map.lhs
      and not (skip_plain and not starts_with_chord)
    then
      local seen_key = (bufnr or 0) .. mode .. new_lhs
      local rhs = map.callback or map.rhs

      if not M._seen[seen_key] and rhs and rhs ~= "" then
        M._seen[seen_key] = true

        local opts = {
          noremap = map.noremap == 1,
          silent = map.silent == 1,
          expr = map.expr == 1,
          nowait = map.nowait == 1,
          script = map.script == 1,
          desc = map.desc,
          buffer = bufnr,
        }

        pcall(vim.keymap.set, mode, new_lhs, rhs, opts)
      end
    end
  end
end

-- Mirror all global mappings across the relevant modes.
function M.sync()
  for _, mode in ipairs(mirror_modes) do
    mirror_mode(mode)
  end
end

-- Mirror buffer-local mappings for a single buffer.
local function sync_buffer(bufnr)
  for _, mode in ipairs(mirror_modes) do
    mirror_mode(mode, bufnr)
  end
end

local sync_timer

-- Coalesce the burst of LazyLoad events during startup into one sync.
local function schedule_sync()
  if sync_timer then
    sync_timer:stop()
  end

  sync_timer = vim.defer_fn(M.sync, 150)
end

-- Explicit insert-mode chords for punctuation that is awkward on the
-- Ukrainian layout. <C-о> is Ctrl + Cyrillic о (the physical `j` key): a
-- bare `:` needs Shift+6 in Ukrainian, so this gives it in one chord.
-- These are Ctrl chords, which the auto-mirror deliberately leaves alone.
local explicit_insert_maps = {
  ["<C-о>"] = ":",
}

-- Register the explicit insert-mode convenience chords.
local function apply_explicit_maps()
  for lhs, rhs in pairs(explicit_insert_maps) do
    vim.keymap.set("i", lhs, rhs, { desc = "Ukrainian: insert " .. rhs })
  end
end

function M.setup()
  vim.o.langmap = build_langmap()
  -- Keep `langmap` from rewriting the rhs of mappings (Neovim default, set
  -- explicitly so it survives config changes).
  vim.o.langremap = false

  local group = vim.api.nvim_create_augroup("UkrainianLayout", { clear = true })

  -- Catch mappings registered by lazy-loaded plugins as they load.
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = { "VeryLazy", "LazyLoad" },
    callback = schedule_sync,
  })

  -- Catch buffer-local mappings from ftplugins and LSP servers.
  vim.api.nvim_create_autocmd({ "FileType", "LspAttach" }, {
    group = group,
    callback = function(event)
      local bufnr = event.buf

      vim.schedule(function()
        sync_buffer(bufnr)
      end)
    end,
  })

  apply_explicit_maps()

  -- Mirror everything already registered (eager keymaps loaded before us).
  vim.schedule(M.sync)

  -- Manual re-sync escape hatch.
  vim.api.nvim_create_user_command("UkrainianLayoutSync", M.sync, {
    desc = "Re-mirror keymaps to the Ukrainian layout",
  })
end

M.setup()

return M
