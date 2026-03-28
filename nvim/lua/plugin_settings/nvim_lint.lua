local eslint_config_files = {
  '.eslintrc', '.eslintrc.js', '.eslintrc.cjs',
  '.eslintrc.yaml', '.eslintrc.yml', '.eslintrc.json',
  'eslint.config.js', 'eslint.config.mjs', 'eslint.config.cjs',
}

local function eslint_configured()
  local dir = vim.fs.dirname(vim.api.nvim_buf_get_name(0))
  return vim.fs.find(eslint_config_files, { path = dir, upward = true })[1] ~= nil
end

require('lint').linters_by_ft = {
  -- ruby = {'rubocop'},
  ruby = {'ruby'},
  -- eruby = {'erb_lint'},
  javascript = {'eslint'},
  bash = {'shellcheck'},
  zsh = {'shellcheck'},
  -- sh = {'shellcheck'}
}

-- vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost", "InsertLeave"}, {
vim.api.nvim_create_autocmd({ "BufWritePost" }, {
  callback = function()
    if vim.bo.filetype == 'javascript' and not eslint_configured() then
      return
    end

    require("lint").try_lint()
  end,
})

-- -- Show LSP/linter/nvim-lint diagnostic for line in popup
-- -- vim.keymap.set('n', '<Leader>k', vim.diagnostic.open_float, opts)
vim.keymap.set('n', ')', vim.diagnostic.open_float, bufopts)
