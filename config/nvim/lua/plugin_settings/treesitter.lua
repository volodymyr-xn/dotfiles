
-- require('nvim-ts-autotag').setup({
--   filetypes = { "html" , "eruby" },
-- })

require("nvim-treesitter.configs").setup({
  -- auto_install = true,

  ensure_installed = {
    "bash",
    "html",
    "javascript",
    "json",
    "lua",
    "regex",
    "go",
    "diff",
    "ruby",
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
    -- enable = false,
    -- disable = { "c", "ruby", "javascript" },
    disable = { "c", "ruby", 'html', "lua", "embedded_template"},
    additional_vim_regex_highlighting = true,
  }
 })

 require('match-up').setup({
   treesitter = {
     stopline = 500
   }
 })

 -- Disable highlight for treesitter groups
 vim.api.nvim_set_hl(0, "@string.special.symbol.ruby", {  })
 vim.api.nvim_set_hl(0, "@variable.member.ruby", {})
 vim.api.nvim_set_hl(0, "@function.builtin.ruby", { })
 -- vim.api.nvim_set_hl(0, "@variable.ruby", { })
 -- vim.api.nvim_set_hl(0, "@function.call.ruby", { })
 vim.api.nvim_set_hl(0, "@function.builtin.ruby", { link = "Statement" })
 vim.api.nvim_set_hl(0, "BlinkCmpLabel", { link = "Statement" })
 -- vim.api.nvim_set_hl(0, "BlinkCmpLabel", { fg = "#ffffff" })
 vim.api.nvim_set_hl(0, "BlinkCmpLabelMatch", { fg = "#ffffff" })
