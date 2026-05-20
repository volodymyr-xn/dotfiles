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
