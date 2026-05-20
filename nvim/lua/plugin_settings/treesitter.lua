
-- require('nvim-ts-autotag').setup({
--   filetypes = { "html" , "eruby" },
-- })

-- NOTE: nvim-treesitter/nvim-treesitter was archived Apr 3 2026 (maintainer burnout after the
-- 0.12 rewrite). We stay on it because the community fork (neovim-treesitter/nvim-treesitter)
-- is still an incompatible early rewrite. The 0.12 breaking change (iter_matches now returns
-- TSNode[] instead of TSNode) is patched in functions/nvim_compat.lua via a get_range guard.
require("nvim-treesitter.configs").setup({
  -- auto_install = true,

  ensure_installed = {
    "bash",
    "javascript",
    "json",
    "lua",
    "regex",
    "go",
    "diff",
    "ruby",
    "python",
    "elixir",
    "sql",
    "vim",
    "yaml",
    "embedded_template",
    "markdown",
    "markdown_inline",
  },
  ignore_install = { "lua" },

  -- TODO: not sure what this used for
  -- illuminate = {
  --   -- disable = { "c", "ruby", "javascript" },
  --   -- enable = true,
  --   enable = false,
  --   loaded = false,
  --   module_path = "illuminate.providers.treesitter"
  -- },
  highlight = {
    enable = true,
    disable = function(lang, buf)
      if lang == "embedded_template" then return true end
      if lang == "markdown" and vim.api.nvim_buf_line_count(buf) > 1000 then return true end

      -- Skip parsing on very large buffers; the incremental parser still
      -- bites at 5k+ lines, especially on nested grammars.
      if vim.api.nvim_buf_line_count(buf) > 3000 then return true end

      -- Skip on huge files where the size lives in one or few lines
      -- (e.g. minified JS / generated bundles).
      local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
      if ok and stats and stats.size > 200 * 1024 then return true end

      return false
    end,
    additional_vim_regex_highlighting = { "ruby" },
  }
 })

-- Common shorthand aliases for fenced code block injection
vim.treesitter.language.register('ruby', 'rb')
vim.treesitter.language.register('javascript', 'js')
vim.treesitter.language.register('typescript', 'ts')
vim.treesitter.language.register('bash', { 'sh', 'shell', 'zsh' })
vim.treesitter.language.register('python', 'py')
vim.treesitter.language.register('go', 'golang')
vim.treesitter.language.register('elixir', { 'ex', 'exs' })
vim.treesitter.language.register('yaml', 'yml')
vim.treesitter.language.register('vim', 'viml')
vim.treesitter.language.register('embedded_template', 'erb')

require('match-up').setup({
   treesitter = {
     stopline = 500
   }
 })

 -- Disable highlight for treesitter groups
-- vim.api.nvim_set_hl(0, "@function.call.ruby", { })
-- vim.api.nvim_set_hl(0, "@function.builtin.ruby", { link = "Statement" })


-- ============ Custom highlight overides ==================
vim.api.nvim_set_hl(0, "@string.special.symbol.ruby", {  })
vim.api.nvim_set_hl(0, "@variable.member.ruby", {})
vim.api.nvim_set_hl(0, "@function.builtin.ruby", { })
vim.api.nvim_set_hl(0, "@function.builtin.ruby", { link = "Statement" })

vim.api.nvim_set_hl(0, "@punctuation.delimiter.ruby", { link = "Statement" })

-- 1. @string.ruby is cleared ({}) - treesitter stops coloring strings, so the underlying
-- vim regex syntax shows through
-- 2. hi! link rubyStringDelimiter Statement - vim's regex syntax already separates quotes
-- (rubyStringDelimiter) from content (rubyString), so the quotes get Statement color
-- while content keeps the String color

vim.api.nvim_set_hl(0, "@string.ruby", {})
vim.cmd("hi! link rubyStringDelimiter Statement")

vim.api.nvim_set_hl(0, "BlinkCmpLabel", { link = "Statement" })
vim.api.nvim_set_hl(0, "BlinkCmpLabelMatch", { fg = "#ffffff" })

vim.api.nvim_set_hl(0, "@binding.pry.ruby", { link = "DiagnosticSignHint" })
vim.api.nvim_set_hl(0, "@ruby.class_dsl.ruby", { link = "Statement" })

vim.api.nvim_create_autocmd("FileType", {
  pattern = "ruby",
  callback = function()
    vim.fn.matchadd("Function", [[\w\+\zs\.\(new\|save\|create\|perform_in\|perform_async\|destroy\|delete_all\|update_all\|update\)(]], 200)
  end,
})
