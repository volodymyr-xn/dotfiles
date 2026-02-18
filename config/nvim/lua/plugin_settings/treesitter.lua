
-- require('nvim-ts-autotag').setup({
--   filetypes = { "html" , "eruby" },
-- })

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
    "embedded_template"
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
    additional_vim_regex_highlighting = { "ruby" },
  }
 })

 require('match-up').setup({
   treesitter = {
     stopline = 500
   }
 })

 -- Disable highlight for treesitter groups
-- vim.api.nvim_set_hl(0, "@function.call.ruby", { })
-- vim.api.nvim_set_hl(0, "@function.builtin.ruby", { link = "Statement" })


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
    vim.fn.matchadd("Function", [[\w\+\.\(new\|save\|create\|perform_in\|perform_async\|destroy\|delete_all\|update_all\|update\)(]], 200)
  end,
})
