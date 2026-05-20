local undo_glow = require("undo-glow")
local hlslens = require("hlslens")

-- Colors are the catppuccin macchiato accents blended ~65% toward the base
-- (#24273a), preserving hue while keeping the glow subtle on a dark bg.
undo_glow.setup({
  animation = {
    enabled = true,
    duration = 1200,
    animation_type = "fade",
    fps = 60,
    -- Holds full color longer at start, then dissolves smoothly
    easing = "out_sine",
  },
  highlights = {
    undo = { hl = "UgUndo", hl_color = { bg = "#604456" } },
    redo = { hl = "UgRedo", hl_color = { bg = "#4b5d55" } },
    yank = { hl = "UgYank", hl_color = { bg = "#615b58" } },
    paste = { hl = "UgPaste", hl_color = { bg = "#435b65" } },
    search = { hl = "UgSearch", hl_color = { bg = "#554b72" } },
  },
})

-- Undo/redo with glow
vim.keymap.set("n", "u", undo_glow.undo, { noremap = true, desc = "Undo with glow" })
vim.keymap.set("n", "<C-r>", undo_glow.redo, { noremap = true, desc = "Redo with glow" })

-- Paste with glow (normal mode; visual-mode overrides in editing.lua remain)
vim.keymap.set("n", "p", undo_glow.paste_below, { noremap = true, desc = "Paste below with glow" })
vim.keymap.set("n", "P", undo_glow.paste_above, { noremap = true, desc = "Paste above with glow" })

-- Search forward: undo-glow flash + hlslens lens (match index/total + scrollbar marks).
local function search_next_with_lens()
  undo_glow.search_next()
  hlslens.start()
end

-- Search backward: undo-glow flash + hlslens lens.
local function search_prev_with_lens()
  undo_glow.search_prev()
  hlslens.start()
end

-- Search navigation with glow + hlslens lens
vim.keymap.set("n", "n", search_next_with_lens, { noremap = true, desc = "Search next with glow + lens" })
vim.keymap.set("n", "N", search_prev_with_lens, { noremap = true, desc = "Search prev with glow + lens" })

-- Highlight yanked text after any yank operation
vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Highlight yanked region",
  callback = undo_glow.yank,
})
