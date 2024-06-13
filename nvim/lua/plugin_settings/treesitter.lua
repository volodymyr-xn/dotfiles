require("nvim-treesitter.configs").setup({
  -- auto_install = true,
  ensure_installed = {
    "bash",
    "html",
    -- "javascript",
    "json",
    "lua",
    "regex",
    "go",
    -- "ruby",
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
    disable = { "c", "ruby" },
    additional_vim_regex_highlighting = true,
  },
})


-- -- Treesitter dosen't highlight Ruby symbols correctly
-- -- Highlight ruby symbols the same as classes
-- vim.api.nvim_set_hl(0, "@symbol.ruby", { link = "Type" })
-- -- Highlight regular ruby variables
-- vim.api.nvim_set_hl(0, "@variable.ruby", { link = "@character.special" })
-- -- Highlight ruby instance variables as properties
-- vim.api.nvim_set_hl(0, "@label.ruby", { link = "@property" })
