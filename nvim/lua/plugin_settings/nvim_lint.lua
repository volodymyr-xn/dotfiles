require('lint').linters_by_ft = {
  ruby = {'rubocop'},
  eruby = {'erb_lint'},
  javascript = {'eslint'},
  bash = {'shellcheck'},
  -- sh = {'shellcheck'}
}

-- vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost", "InsertLeave"}, {
vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost"}, {
  -- pattern = {"*.rb", "*.js", "*.html.erb", "*.haml", "*.spec"},
  callback = function()
    require("lint").try_lint()
    -- local lint_status, lint = pcall(require, "lint")
    -- if lint_status then
    --   lint.try_lint()
    -- end
  end,
})
