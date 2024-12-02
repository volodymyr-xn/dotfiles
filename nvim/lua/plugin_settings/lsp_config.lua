require("mason").setup()
require("mason-lspconfig").setup({
  -- A list of servers to automatically install if they're not already installed. Example: { "rust_analyzer@nightly", "lua_ls" }
  -- This setting has no relation with the `automatic_installation` setting.
  -- ensure_installed = { "lua_ls", "ts_ls", "cssls", "tailwindcss"},
  ensure_installed = { "lua_ls", "ts_ls", "cssls", "tailwindcss", "ruby_lsp"},
  -- Whether servers that are set up (via lspconfig) should be automatically installed if they're not already installed.
  automatic_installation = false
})

local capabilities = require("cmp_nvim_lsp").default_capabilities()
local lspconfig = require('lspconfig')
-- Maybe depreacated:
-- require 'lspconfig/configs'

-- Diable LSP logfile ($HOME/.local/state/nvim/lsp.log)
-- vim.lsp.set_log_level("off")

-- ================================== Typecraft config
-- lspconfig.ruby_lsp.setup({
--   capabilities = capabilities
-- })
-- ====================================

-- See `:help vim.lsp.*` for documentation on any of the below functions
local bufopts = { noremap=true, silent=true, buffer=bufnr }
-- Some help hints about method and classes in popup window
-- Works well for Ruby and Rails standard library, also for gems
vim.keymap.set('n', 'go', vim.lsp.buf.hover, bufopts)

-- Format by null_ls
vim.keymap.set('n', '<Leader>=', vim.lsp.buf.format, bufopts)

-- Go to definition. Works, but not works initialy when LSP client is not attached
-- REALLY COOL!!!
vim.keymap.set('n', 'gd', vim.lsp.buf.definition, bufopts)

-- Find references of variable/constant/class/method accross files
-- REALLY COOL!!!
vim.keymap.set('n', 'gr', vim.lsp.buf.references, bufopts)

-- Rename method/variable/constant accross files
-- REALLY COOL!!!
vim.keymap.set('n', 'gv', vim.lsp.buf.rename, bufopts)

vim.keymap.set('n', 'ga', vim.lsp.buf.code_action, {})

-- Mappings.
-- See `:help vim.diagnostic.*` for documentation on any of the below functions
-- Use an on_attach function to only map the following keys
-- after the language server attaches to the current buffer
local on_attach = function(client, bufnr)
  -- vim.lsp.codelens.refresh()
end

-- Initial refresh codelens
-- vim.api.nvim_create_autocmd('User', {
--     pattern = 'LspAttached',
--     once = true,
--     callback = vim.lsp.codelens.refresh,
-- })

local lsp_flags = {
  -- This is the default in Nvim 0.7+
  -- debounce_text_changes = 150,
}

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

lspconfig['ts_ls'].setup{
  -- on_attach = on_attach,
  flags = lsp_flags,
  capabilities = capabilities
}

-- lspconfig.emmet_language_server.setup({
--   filetypes = { "eruby", "html" },
--   -- Read more about this options in the [vscode docs](https://code.visualstudio.com/docs/editor/emmet#_emmet-configuration).
--   -- **Note:** only the options listed in the table are supported.
--   init_options = {
--     --- @type string[]
--     excludeLanguages = {},
--     --- @type string[]
--     extensionsPath = {},
--     --- @type table<string, any> [Emmet Docs](https://docs.emmet.io/customization/preferences/)
--     preferences = {},
--     --- @type boolean Defaults to `true`
--     showAbbreviationSuggestions = true,
--     --- @type "always" | "never" Defaults to `"always"`
--     showExpandedAbbreviation = "always",
--     --- @type boolean Defaults to `false`
--     showSuggestionsAsSnippets = false,
--     --- @type table<string, any> [Emmet Docs](https://docs.emmet.io/customization/syntax-profiles/)
--     syntaxProfiles = {},
--     --- @type table<string, string> [Emmet Docs](https://docs.emmet.io/customization/snippets/#variables)
--     variables = {},
--   },
-- })


function configureSolargraph()
  print("Using Solargraph LSP")

  lspconfig['solargraph'].setup{
    cmd = {'env', 'RUBY_YJIT_ENABLE=1', 'solargraph', 'stdio' },
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

lspconfig['rubocop'].setup({
  cmd = { 'env', 'RUBY_YJIT_ENABLE=1', 'bundle', 'exec', 'rubocop', '--lsp' },
  flags = lsp_flags,
  capabilities = capabilities,
})


function configureRubyLSP()
  print("Using ruby_lsp LSP")

  lspconfig['ruby_lsp'].setup({
    cmd = {'env', 'RUBY_YJIT_ENABLE=1', 'ruby-lsp' },
    flags = lsp_flags,
    capabilities = capabilities,
    -- filetypes = { 'ruby'},
    filetypes = { 'ruby', 'eruby'},
    init_options = {
      enabledFeatures = {
        -- Disable LSP highlight of code
        -- "semanticHighlighting",
        -- "diagnostics",
        "documentSymbol",
        "documentLink",
        "hover",
        "foldingRange",
        "selectionRange",
        "formatting",
        "onTypeFormatting",
        "diagnostic",
        "codeAction",
        "codeActions",
        "codeActionResolve",
        "documentHighlight",
        "inlayHint",
        "completion",
        "codeLens",
        "definition",
        "references",
        "workspaceSymbol",
        "signatureHelp",
      }
    },
  })
end

local ruby_major_version = readRubyVersion()

configureRubyLSP()
-- configureSolargraph()

-- -- Enable Ruby-lsp on Ruby 3.0+ projekts
-- if (ruby_major_version and ruby_major_version >= 3) then
--   configureRubyLSP()
-- else
--   configureSolargraph()
-- end

lspconfig['tailwindcss'].setup{}

-- lspconfig['html'].setup{
--   on_attach = on_attach,
--   flags = lsp_flags,
--   capabilities = capabilities,
--   diagnostics = true,
--   filetypes = { 'html', 'eruby'},
-- }

---------------------------------
-- Floating diagnostics message
---------------------------------
vim.diagnostic.config({
  -- float = { source = "always", border = border },
  float = { source = "always"},
  -- virtual_text = true,
  signs = true,
  virtual_text = {
    source = "always",  -- Or "if_many"
    -- prefix = '⚠️',
  },
  -- if you want diagnostics to update while in insert mode.
  update_in_insert = false,
  severity_sort = true
})
--

-- local signs = { Error = "⛔", Warn = "🔶", Hint = "💡", Info = "🔶" }
local signs = { Error = "⛔", Warn = "⚠️", Hint = "💡", Info = "⚠️" }
for type, icon in pairs(signs) do
  local hl = "DiagnosticSign" .. type
  vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
end

