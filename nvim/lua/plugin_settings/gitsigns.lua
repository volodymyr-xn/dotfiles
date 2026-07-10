require('gitsigns').setup({
  signs = {
    add          = { text = '+' },
    change       = { text = '~' },
    delete       = { text = '-' },
    topdelete    = { text = '---' },
    changedelete = { text = '~-' },
    untracked    = { text = '~' },
  },
  signcolumn = true,  -- Toggle with `:Gitsigns toggle_signs`
  -- linehl = true,
  -- Attach to untracked files too, so new files get signs and line highlights
  -- (OneDiff v2 highlights new files the same as modified ones).
  attach_to_untracked = true,
  -- Group deletions then additions into contiguous blocks like `git diff`,
  -- overriding Neovim 0.12's default `linematch:40` (inherited from diffopt),
  -- which interleaves matching added/removed lines within a hunk -- noisy in
  -- OneDiff's inline deleted-line view. Only affects gitsigns, not
  -- :diffsplit/fugitive.
  diff_opts = { linematch = 0 },
})
