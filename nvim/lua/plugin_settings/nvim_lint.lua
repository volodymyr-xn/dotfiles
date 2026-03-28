local lint = require('lint')

local eslint_config_files = {
  '.eslintrc', '.eslintrc.js', '.eslintrc.cjs',
  '.eslintrc.yaml', '.eslintrc.yml', '.eslintrc.json',
  'eslint.config.js', 'eslint.config.mjs', 'eslint.config.cjs',
  'package.json',
}

local function eslint_configured()
  local dir = vim.fs.dirname(vim.api.nvim_buf_get_name(0))
  local found = vim.fs.find(eslint_config_files, { path = dir, upward = true })[1]

  if not found then
    return false
  end

  if vim.fn.fnamemodify(found, ':t') ~= 'package.json' then
    return true
  end

  local ok, data = pcall(vim.fn.readfile, found)
  if not ok then
    return false
  end

  local ok2, decoded = pcall(vim.fn.json_decode, table.concat(data, ''))
  return ok2 and decoded ~= nil and decoded.eslintConfig ~= nil
end

local function ft_uses_eslint()
  local linters = lint.linters_by_ft[vim.bo.filetype] or {}
  return vim.tbl_contains(linters, 'eslint')
end

lint.linters_by_ft = {
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
    if ft_uses_eslint() and not eslint_configured() then
      return
    end

    lint.try_lint()
  end,
})

-- -- Show LSP/linter/nvim-lint diagnostic for line in popup
-- -- vim.keymap.set('n', '<Leader>k', vim.diagnostic.open_float, opts)
vim.keymap.set('n', ')', vim.diagnostic.open_float, bufopts)
