local ai = require("mini.ai")

-- Extended text objects: af/if (function), ac/ic (class), a,/i, (argument), an/in (next), al/il (last)
ai.setup({
  n_lines = 100,
})

-- 0.12 adds built-in visual-mode an/in for treesitter node selection which
-- conflicts with mini.ai's an/in (around/inside next). Reclaim the keys.
vim.keymap.del("x", "an", { silent = true })
vim.keymap.del("x", "in", { silent = true })
