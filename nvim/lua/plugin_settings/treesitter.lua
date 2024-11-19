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
  illuminate = {
    -- disable = { "c", "ruby", "javascript" },
    enable = true,
    loaded = false,
    module_path = "illuminate.providers.treesitter"
  },
  highlight = {
    enable = true,
    -- disable = { "c", "ruby", "javascript" },
    disable = { "c", "ruby", 'html'},
    additional_vim_regex_highlighting = true,
  },
})

-- Make eruby filetype to use html treesitter rules
vim.treesitter.language.register("html", "eruby")
