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
    -- iv/av: identifier with `_` and `-` as word chars (e.g. SCSS
    -- `_import-section-max-width`, `.admin-action`). `%f[%w_]` anchors
    -- the match to the identifier start so mid-word cursors still
    -- select the whole identifier, not cursor-to-end. Leaves `ciw`
    -- defaults intact.
    v = { "%f[%w_%-][%w_][%w_%-]*" },
    -- Yield `i%`/`a%` to vim-matchup. Without this, mini.ai's generic
    -- any-char handler treats `%` as a paired delimiter, scans for it,
    -- finds nothing, and aborts before vim-matchup's mapping can fire.
    ["%"] = false,
  },
})

-- 0.12 adds built-in visual-mode an/in for treesitter node selection which
-- conflicts with mini.ai's an/in (around/inside next). Reclaim the keys.
vim.keymap.del("x", "an", { silent = true })
vim.keymap.del("x", "in", { silent = true })
