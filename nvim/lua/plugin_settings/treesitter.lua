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
    disable = { "c", "ruby", 'html', "lua"},
    additional_vim_regex_highlighting = true,
  }
 })
