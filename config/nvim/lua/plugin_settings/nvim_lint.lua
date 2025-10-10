require('lint').linters_by_ft = {
  -- ruby = {'rubocop'},
  ruby = {'ruby'},
  -- eruby = {'erb_lint'},
  javascript = {'eslint'},
  bash = {'shellcheck'},
  zsh = {'shellcheck'},
  sh = {'shellcheck'}
}

-- vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost", "InsertLeave"}, {
vim.api.nvim_create_autocmd({ "BufWritePost" }, {
  callback = function()
    -- try_lint without arguments runs the linters defined in `linters_by_ft`
    -- for the current filetype
    require("lint").try_lint()
  end,
})

-- -- Show LSP/linter/nvim-lint diagnostic for line in popup
-- -- vim.keymap.set('n', '<Leader>k', vim.diagnostic.open_float, opts)
vim.keymap.set('n', ')', vim.diagnostic.open_float, bufopts)
