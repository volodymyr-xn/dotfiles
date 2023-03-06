-- ---------------------------------
require("nvim-treesitter.configs").setup({
  -- auto_install = true,
  ensure_installed = {
    "bash",
    "html",
    "javascript",
    "json",
    "lua",
    "regex",
    "ruby",
    "elixir",
    "sql",
    "vim",
    "yaml",
    'markdown',
    'markdown_inline'
  },
  highlight = { enable = false },
  indent = { enable = true },

  -- For HTML tags
  autotag = {
    enable = true,
    filetypes = {
      "html",
      "javascript",
    },
  },

  -- - EXPERIMENTAL settings
  refactor = {
    smart_rename = { enable = true, keymaps = { smart_rename = 'grr' } },
    highlight_definitions = { enable = true },
  },
  textsubjects = {
    enable = true,
    lookahead = true,
    keymaps = {
      ['.'] = 'textsubjects-smart',
      [';'] = 'textsubjects-container-outer',
      ['i;'] = 'textsubjects-container-inner',
    },
  },
  endwise = { enable = true },
  matchup = { enable = true },
})


-- Treesitter dosen't highlight Ruby symbols correctly
-- Highlight ruby symbols the same as classes
vim.api.nvim_set_hl(0, "@symbol.ruby", { link = "Type" })
-- Highlight regular ruby variables
vim.api.nvim_set_hl(0, "@variable.ruby", { link = "@character.special" })
-- Highlight ruby instance variables as properties
vim.api.nvim_set_hl(0, "@label.ruby", { link = "@property" })
