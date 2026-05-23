-- Defer match-pair recompute so updates run after a short delay instead of
-- synchronously on every cursor move; keeps insert mode responsive.
vim.g.matchup_matchparen_deferred = 1
vim.g.matchup_matchparen_timeout = 100
vim.g.matchup_matchparen_insert_timeout = 30

require('match-up').setup({
  treesitter = {
    stopline = 500
  }
})

-- Mirror i%/a% under id/ad so the matchup pair (def...end, if...end,
-- do...end, html/erb tag pairs, etc.) is reachable with `d` as well as
-- with `%`. Vim's timeoutlen-based resolver picks the longer 2-char
-- map (`id`/`ad`) over mini.ai's 1-char `i`/`a` prefix, so this works
-- without disabling mini.ai's generic any-char handler for `d`.
vim.keymap.set({ "o", "x" }, "id", "<Plug>(matchup-i%)",
  { silent = true, desc = "Inside matchup pair (def...end, etc)" })
vim.keymap.set({ "o", "x" }, "ad", "<Plug>(matchup-a%)",
  { silent = true, desc = "Around matchup pair (def...end, etc)" })
