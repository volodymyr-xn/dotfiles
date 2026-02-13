
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
    "python",
    "elixir",
    "sql",
    "scss",
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
    -- disable = { "c", "ruby", 'html', "lua", "scss", "embedded_template"},
    additional_vim_regex_highlighting = true,
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

local ns = vim.api.nvim_create_namespace("ruby_string_quotes")

local function highlight_ruby_quotes(buf)
  if not vim.api.nvim_buf_is_valid(buf) then return end
  if vim.bo[buf].filetype ~= "ruby" then return end

  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  local ok, parser = pcall(vim.treesitter.get_parser, buf, "ruby")
  if not ok or not parser then return end

  local trees = parser:parse()
  if not trees or not trees[1] then return end

  local query = vim.treesitter.query.parse("ruby", "(string) @str")

  for id, node in query:iter_captures(trees[1]:root(), buf) do
    local sr, sc, er, ec = node:range()
    vim.api.nvim_buf_set_extmark(buf, ns, sr, sc, {
      end_row = sr,
      end_col = sc + 1,
      hl_group = "Statement",
      priority = 200,
    })
    if ec > sc + 1 then
      vim.api.nvim_buf_set_extmark(buf, ns, er, ec - 1, {
        end_row = er,
        end_col = ec,
        hl_group = "Statement",
        priority = 200,
      })
    end
  end
end

vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "TextChanged", "TextChangedI", "FileType" }, {
  pattern = { "*.rb", "ruby" },
  callback = function(args)
    vim.schedule(function()
      highlight_ruby_quotes(args.buf)
    end)
  end,
})

vim.api.nvim_set_hl(0, "BlinkCmpLabel", { link = "Statement" })
vim.api.nvim_set_hl(0, "BlinkCmpLabelMatch", { fg = "#ffffff" })
