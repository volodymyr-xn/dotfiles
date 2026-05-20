require('outline').setup({
  providers = {
    priority = { 'lsp', 'coc', 'markdown', 'norg', 'treesitter' },
  },
  symbol_folding = {
    -- Depth past which nodes will be folded by default. Set to false to unfold all on open.
    autofold_depth = 1,
    -- When to auto unfold nodes
    auto_unfold = {
      -- Auto unfold currently hovered symbol
      hovered = false,
      -- Auto fold when the root level only has this many nodes.
      -- Set true for 1 node, false for 0.
      only = true,
    },
    markers = { '', '' },
  },
})
