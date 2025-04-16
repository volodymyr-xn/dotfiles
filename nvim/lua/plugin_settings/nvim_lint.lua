require('lint').linters_by_ft = {
  -- ruby = {'rubocop'},
  -- eruby = {'erb_lint'},
  javascript = {'eslint'},
  bash = {'shellcheck'},
  -- sh = {'shellcheck'}
}

-- vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost", "InsertLeave"}, {
--
vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost"}, {
  -- pattern = {"*.rb", "*.js", "*.html.erb", "*.haml", "*.spec"},
  -- pattern = {"*.html.erb"},
  callback = function()
    require("lint").try_lint()
    -- local lint_status, lint = pcall(require, "lint")
    -- if lint_status then
    --   lint.try_lint()
    -- end
  end,
})
--
-- -- Show LSP/linter/nvim-lint diagnostic for line in popup
-- -- vim.keymap.set('n', '<Leader>k', vim.diagnostic.open_float, opts)
vim.keymap.set('n', ')', vim.diagnostic.open_float, bufopts)
