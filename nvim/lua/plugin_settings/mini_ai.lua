local ai = require("mini.ai")
local ts_spec = ai.gen_spec.treesitter

-- Extended text objects: af/if (function), ac/ic (class), a,/i, (argument), an/in (next), al/il (last)
-- `f` and `c` are overridden to use treesitter queries so they match real
-- function/method/class definitions (including Ruby `def ... end` and
-- `class ... end`), not just paren-call expressions.
ai.setup({
  n_lines = 100,
  custom_textobjects = {
    f = ts_spec({ a = "@function.outer", i = "@function.inner" }),
    c = ts_spec({ a = "@class.outer", i = "@class.inner" }),
  },
})

-- 0.12 adds built-in visual-mode an/in for treesitter node selection which
-- conflicts with mini.ai's an/in (around/inside next). Reclaim the keys.
vim.keymap.del("x", "an", { silent = true })
vim.keymap.del("x", "in", { silent = true })
