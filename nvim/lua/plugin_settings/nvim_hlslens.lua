-- Paints the hlslens lens highlights: a peach pill for the nearest match
-- ([󰍉 2/6]) and a dim chip for the other visible matches. Re-applied on
-- ColorScheme because loading a colorscheme clears user-defined groups.
local function set_hlslens_highlights()
  vim.api.nvim_set_hl(0, "HlSearchLensNear", { fg = "#181926", bg = "#f5a97f", bold = true })
  vim.api.nvim_set_hl(0, "HlSearchLens", { fg = "#cad3f5", bg = "#363a4f" })
end

set_hlslens_highlights()

-- Keep the custom lens colors alive across colorscheme switches.
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("HlslensCustomHighlights", { clear = true }),
  callback = set_hlslens_highlights,
})

-- Builds the search-direction indicator (n/N + relative count) hlslens prefixes
-- to a lens, mirroring the plugin default so jump direction stays readable.
local function search_indicator(rel_idx)
  local sfw = vim.v.searchforward == 1
  local abs = math.abs(rel_idx)
  if abs > 1 then
    return ("%d%s"):format(abs, sfw ~= (rel_idx > 1) and "N" or "n")
  elseif abs == 1 then
    return sfw ~= (rel_idx == 1) and "N" or "n"
  end
  return ""
end

-- Custom lens renderer: nearest match becomes a glyphed peach pill ([󰍉 2/6]),
-- non-nearest matches a compact dim index, replacing the plain [2/6] default.
local function override_lens(render, pos_list, nearest, idx, rel_idx)
  local indicator = search_indicator(rel_idx)
  local lnum, col = unpack(pos_list[idx])
  local text, hl
  if nearest then
    local cnt = #pos_list
    if indicator ~= "" then
      text = (" 󰍉 %s %d/%d "):format(indicator, idx, cnt)
    else
      text = (" 󰍉 %d/%d "):format(idx, cnt)
    end
    hl = "HlSearchLensNear"
  else
    text = indicator ~= "" and (" %s %d "):format(indicator, idx) or (" %d "):format(idx)
    hl = "HlSearchLens"
  end
  render.setVirt(0, lnum - 1, col - 1, { { " " }, { text, hl } }, nearest)
end

-- Wires hlslens into nvim-scrollbar's search handler. Calling this internally
-- runs hlslens.setup with a build_position_cb that pushes match positions to
-- scrollbar, so search hits appear as scrollbar marks. Must run after
-- scrollbar.setup; lazy `dependencies` in plugins_install.lua guarantees that.
-- The override_lens override is forwarded into hlslens' config.
require("scrollbar.handlers.search").setup({ override_lens = override_lens })

local kopts = { noremap = true, silent = true }

-- Word-under-cursor search forward + refresh lens (match index/total + scrollbar marks).
vim.keymap.set("n", "*", [[*<Cmd>lua require("hlslens").start()<CR>]], kopts)

-- Word-under-cursor search backward + refresh lens.
vim.keymap.set("n", "#", [[#<Cmd>lua require("hlslens").start()<CR>]], kopts)

-- Like `*` but without word boundaries.
vim.keymap.set("n", "g*", [[g*<Cmd>lua require("hlslens").start()<CR>]], kopts)

-- Like `#` but without word boundaries.
vim.keymap.set("n", "g#", [[g#<Cmd>lua require("hlslens").start()<CR>]], kopts)

-- Search forward + refresh lens (match index/total + scrollbar marks).
vim.keymap.set("n", "n", [[<Cmd>execute('normal! ' . v:count1 . 'n')<CR><Cmd>lua require('hlslens').start()<CR>]], kopts)

-- Search backward + refresh lens.
vim.keymap.set("n", "N", [[<Cmd>execute('normal! ' . v:count1 . 'N')<CR><Cmd>lua require('hlslens').start()<CR>]], kopts)

-- Clears highlighting and stops the lens.
vim.keymap.set("n", "<Leader>l", "<Cmd>noh<CR><Cmd>lua require('hlslens').stop()<CR>", kopts)
