require("mason").setup()
require("mason-lspconfig").setup({
  -- A list of servers to automatically install if they're not already installed. Example: { "rust_analyzer@nightly", "lua_ls" }
  -- This setting has no relation with the `automatic_installation` setting.
  ensure_installed = { "lua_ls", "tsserver", "ruby_ls", "cssls", "tailwindcss"},
  -- Whether servers that are set up (via lspconfig) should be automatically installed if they're not already installed.
  -- This setting has no relation with the `ensure_installed` setting.
  -- Can either be:
  automatic_installation = false
})

-- require 'lspconfig/configs'

-- require("neodev").setup({ })

-- Mappings.
-- See `:help vim.diagnostic.*` for documentation on any of the below functions
-- Use an on_attach function to only map the following keys
-- after the language server attaches to the current buffer
local on_attach = function(client, bufnr)
  -- Mappings.
  -- See `:help vim.lsp.*` for documentation on any of the below functions
  local bufopts = { noremap=true, silent=true, buffer=bufnr }

  ------------- Good mappings i use ------------------------------------------
  -- Show LSP/linter diagnostic for line in popup
  -- vim.keymap.set('n', '<Leader>k', vim.diagnostic.open_float, opts)
  vim.keymap.set('n', '`', vim.diagnostic.open_float, bufopts)

  -- Some help hints about method and classes in popup window
  -- Works well for Ruby and Rails standard library, also for gems
  vim.keymap.set('n', 'go', vim.lsp.buf.hover, bufopts)

  -- Format by null_ls
  -- vim.keymap.set('n', '<Leader>=', vim.lsp.buf.format, bufopts)

  -- Go to definition. Works, but not works initialy when LSP client is not attached
  -- REALLY COOL!!!
  vim.keymap.set('n', 'gd', vim.lsp.buf.definition, bufopts)

  -- Find references of variable/constant/class/method accross files
  -- REALLY COOL!!!
  vim.keymap.set('n', 'gr', vim.lsp.buf.references, bufopts)

  -- Rename method/variable/constant accross files
  -- REALLY COOL!!!
  vim.keymap.set('n', 'gv', vim.lsp.buf.rename, bufopts)

  -- Experimental use Telescope for LSP ---------------------------------------------
  -- keymap.set("n", "gr", "<cmd>Telescope lsp_references<CR>", opts) -- show definition, references
  -- keymap.set("n", "gd", "<cmd>Telescope lsp_definitions<CR>", opts) -- see definition and make edits in window
  -- keymap.set("n", "<leader>D", "<cmd>Telescope diagnostics bufnr=0<CR>", opts) -- show  diagnostics for file
  -- keymap.set("n", "<leader>rn", ":IncRename ", opts) -- smart rename
  -- keymap.set("n", "[d", vim.diagnostic.goto_prev, opts) -- jump to previous diagnostic in buffer
  -- keymap.set("n", "]d", vim.diagnostic.goto_next, opts) -- jump to next diagnostic in buffer

  ---------------------------------------------
  -- TODO: setup LSP rename

  --- Doesnt work for Ruby with Solargraph -----
  ----------------------------------------------
  ----------------------------------------------
  ----------------------------------------------
  ----------------------------------------------
  ----------------------------------------------
  --- Doesnt work for Ruby with Solargraph
  -- vim.keymap.set('n', 'gD', vim.lsp.buf.type_definition, bufopts)
  -- vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, bufopts)
  -- vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, bufopts)
  vim.keymap.set('n', '<Leader>gv', vim.lsp.buf.code_action, bufopts)

  -- This mapping conflict with vim-tmux-navigator
    -- on_attach = function(client, buffer)
  setup_diagnostics(client, buffer)
    -- end,
end

local lsp_flags = {
  -- This is the default in Nvim 0.7+
  -- debounce_text_changes = 150,
}

local capabilities = require("cmp_nvim_lsp").default_capabilities()
local lspconfig = require('lspconfig')

-- lspconfig['lua_ls'].setup{
--   on_attach = on_attach,
--   flags = lsp_flags,
--   settings = {
--     Lua = {
--       completion = {
--         callSnippet = "Replace"
--       }
--     }
--   }
-- }

lspconfig['cssls'].setup{
  on_attach = on_attach,
  flags = lsp_flags,
  capabilities = capabilities
}

lspconfig['tsserver'].setup{
  on_attach = on_attach,
  flags = lsp_flags,
  capabilities = capabilities
}

lspconfig['tsserver'].setup{
  on_attach = on_attach,
  flags = lsp_flags,
  capabilities = capabilities
}


function configureSolargraph()
  lspconfig['solargraph'].setup{
    on_attach = on_attach,
    flags = lsp_flags,
    capabilities = capabilities,
    filetypes = { 'ruby', 'eruby'},
    -- Disable built in Solargraph Rubocop diagnostics
    -- Use linter
    settings = {
      solargraph = {
        diagnostics = false
      }
    },
    useBundler = true
  }
end

local enabled_features = {
}

function configureRubyLS()
  lspconfig['ruby_ls'].setup({
    on_attach = on_attach,
    flags = lsp_flags,
    capabilities = capabilities,
    filetypes = { 'ruby', 'eruby'},
    init_options = {
				enabledFeatures = {
          "documentSymbol",
          "documentLink",
          "hover",
          "foldingRange",
          "selectionRange",
          -- "semanticHighlighting",
          "formatting",
          "onTypeFormatting",
          "diagnostic",
          "codeAction",
          "codeActionResolve",
          "documentHighlight",
          "inlayHint",
          "completion",
          "codeLens",
          "definition",
          "showSyntaxTree",
          "workspaceSymbol",
          "signatureHelp",
        }
			},
  })
end

local ruby_major_version = readRubyVersion()

if (ruby_major_version and ruby_major_version >= 3) then
  -- Enable Ruby-lsp on Ruby 3.0+ projekts
  configureRubyLS()
  -- configureSolargraph()
  print("Ruby version: " .. ruby_major_version .. ". Using ruby_ls LSP")
elseif ruby_major_version then
  configureSolargraph()
  -- Enable solargraph on "ruby"
  print("Ruby version: " .. ruby_major_version .. ". Using Solargraph LSP")
else
  configureSolargraph()
end

lspconfig['tailwindcss'].setup{}

-- lspconfig['html'].setup{
--   on_attach = on_attach,
--   flags = lsp_flags,
--   capabilities = capabilities,
--   -- diagnostics = true,
--   filetypes = { 'html', 'eruby'},
-- }

---------------------------------
-- Floating diagnostics message
---------------------------------
vim.diagnostic.config({
  -- float = { source = "always", border = border },
  float = { source = "always"},
  -- virtual_text = true,
  -- signs = true,
  virtual_text = {
    source = "always",  -- Or "if_many"
    -- prefix = '⚠️',
  },
  -- if you want diagnostics to update while in insert mode.
  update_in_insert = false,
  severity_sort = true
})
--

-- local signs = { Error = " ", Warn = " ", Hint = " ", Info = " " }
local signs = { Error = "⛔", Warn = "⚠️ ", Hint = "💡", Info = "⚠️ " }
-- local signs = { Error = "⛔", Warn = "⚠️ ", Hint = "💡", Info = "ℹ️ " }
for type, icon in pairs(signs) do
  local hl = "DiagnosticSign" .. type
  vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
end

---------------------------------
-- Auto commands
---------------------------------
-- Open popup window with Linters info on hoold
-- vim.cmd([[ autocmd! CursorHold,CursorHoldI * lua vim.diagnostic.open_float(nil, {focus=false})]])
