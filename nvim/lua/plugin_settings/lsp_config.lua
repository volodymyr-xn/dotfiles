require("mason").setup()
require("mason-lspconfig").setup({
  -- A list of servers to automatically install if they're not already installed. Example: { "rust_analyzer@nightly", "lua_ls" }
  -- This setting has no relation with the `automatic_installation` setting.
  -- ensure_installed = { "lua_ls", "ts_ls", "cssls", "herb_ls", "tailwindcss"},
  -- ensure_installed = { "lua_ls", "ts_ls", "cssls", "herb_ls", "tailwindcss", "ruby_lsp"},
  ensure_installed = { "ts_ls", "cssls", "herb_ls"},
  -- Whether servers that are set up (via lspconfig) should be automatically installed if they're not already installed.
  automatic_installation = false
})

-- lsp-status drives the `get_lsp_status()` component in lualine. Needs
-- three hooks to actually report anything: register_progress() once,
-- capabilities merge so the server advertises progress support, and
-- on_attach to start listening on each new client.
local lsp_status = require("lsp-status")
lsp_status.register_progress()

local capabilities = require("cmp_nvim_lsp").default_capabilities()
capabilities = vim.tbl_extend("keep", capabilities, lsp_status.capabilities)

-- See `:help vim.lsp.*` for documentation on any of the below functions
local bufopts = { noremap=true, silent=true, buffer=bufnr }
-- Some help hints about method and classes in popup window
-- Works well for Ruby and Rails standard library, also for gems
vim.keymap.set('n', 'go', vim.lsp.buf.hover, vim.tbl_extend('force', bufopts, { desc = "LSP hover" }))

-- Format by null_ls
vim.keymap.set('n', '<Leader>=', vim.lsp.buf.format, vim.tbl_extend('force', bufopts, { desc = "Format buffer" }))

-- Go to definition. Works, but not works initialy when LSP client is not attached
-- REALLY COOL!!!
-- upd 2026: not really cool
vim.keymap.set('n', 'gd', vim.lsp.buf.definition, vim.tbl_extend('force', bufopts, { desc = "Go to definition" }))

-- -- Find references of variable/constant/class/method accross files
-- -- REALLY COOL!!!
vim.keymap.set('n', 'gr', vim.lsp.buf.references, vim.tbl_extend('force', bufopts, { desc = "Find references" }))

-- -- Rename method/variable/constant accross files
-- -- REALLY COOL!!!
vim.keymap.set('n', 'gb', vim.lsp.buf.rename, vim.tbl_extend('force', bufopts, { desc = "Rename symbol" }))

-- LSP code actions
vim.keymap.set('n', 'ga', vim.lsp.buf.code_action, { desc = "Code actions" })

-- Mappings.
-- See `:help vim.diagnostic.*` for documentation on any of the below functions
-- Use an on_attach function to only map the following keys
-- after the language server attaches to the current buffer
local on_attach = function(client, bufnr)
  -- Subscribe this client to lsp-status' progress/diagnostic streams.
  lsp_status.on_attach(client)
  -- vim.lsp.codelens.refresh()
end

-- Initial refresh codelens
-- vim.api.nvim_create_autocmd('User', {
--     pattern = 'LspAttached',
--     once = true,
--     callback = vim.lsp.codelens.refresh,
-- })

local lsp_flags = {
  -- Coalesce `didChange` notifications so the server doesn't process every
  -- keystroke; trades a bit of diagnostic freshness for typing responsiveness.
  debounce_text_changes = 250,
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

vim.lsp.config('cssls', {
  on_attach = on_attach,
  flags = lsp_flags,
  capabilities = capabilities
})

vim.lsp.config('ts_ls', {
  on_attach = on_attach,
  flags = lsp_flags,
  capabilities = capabilities
})

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


-- function configureSolargraph()
--   print("Using Solargraph LSP")
--
--   vim.lsp.config('solargraph', {
--     -- Using YJIT with lsp can make 100% CPU usage
--     -- cmd = {'env', 'RUBY_YJIT_ENABLE=1', 'solargraph', 'stdio' },
--     on_attach = on_attach,
--     flags = lsp_flags,
--     capabilities = capabilities,
--     filetypes = { 'ruby', 'eruby'},
--     -- Disable built in Solargraph Rubocop diagnostics
--     -- Use linter instead
--     settings = {
--       solargraph = {
--         diagnostics = false
--       }
--     },
--     -- useBundler = true
--   })
-- end

-- lspconfig['rubocop'].setup({
--   -- Using YJIT with lsp can make 100% CPU usage
--   -- cmd = { 'env', 'RUBY_YJIT_ENABLE=1', 'bundle', 'exec', 'rubocop', '--lsp' },
--   flags = lsp_flags,
--   capabilities = capabilities,
-- })


-- function configureRubyLSP()
--   print("Using ruby_lsp LSP")
--
--   vim.lsp.config('ruby_lsp', {
--   -- Using YJIT with lsp can make 100% CPU usage
--     -- cmd = {'env', 'RUBY_YJIT_ENABLE=1', 'ruby-lsp' },
--     flags = lsp_flags,
--     capabilities = capabilities,
--     -- filetypes = { 'ruby'},
--     filetypes = { 'ruby', 'eruby'},
--     init_options = {
--       enabledFeatures = {
--         -- Disable LSP highlight of code
--         -- "semanticHighlighting",
--         -- "diagnostics",
--         "documentSymbol",
--         "documentLink",
--         "hover",
--         "foldingRange",
--         "selectionRange",
--         "formatting",
--         "onTypeFormatting",
--         "diagnostic",
--         "codeAction",
--         "codeActions",
--         "codeActionResolve",
--         "documentHighlight",
--         "inlayHint",
--         "completion",
--         "codeLens",
--         "definition",
--         "references",
--         "workspaceSymbol",
--         "signatureHelp",
--       }
--     },
--   })
-- end

-- local ruby_major_version, ruby_minor_version = readRubyVersion()
-- if (ruby_major_version > 3 and ruby_minor_version > 4) then
--   configureRubyLSP()
-- else
--   configureSolargraph()
-- end

-- vim.lsp.config('tailwindcss', {})

-- lspconfig['html'].setup{
--   on_attach = on_attach,
--   flags = lsp_flags,
--   capabilities = capabilities,
--   diagnostics = true,
--   filetypes = { 'html', 'eruby'},
-- }

-- Deprecated
-- require('lspconfig').herb_ls.setup()
-- vim.lsp.config('herb_ls', {})

-- vim.lsp.enable("solargraph")
vim.lsp.enable("ts_ls")
vim.lsp.enable("cssls")
vim.lsp.enable("herb_ls")


---------------------------------
-- Floating diagnostics message
---------------------------------
local sev = vim.diagnostic.severity
vim.diagnostic.config({
  float = { source = "always" },
  virtual_text = { source = "always" },
  update_in_insert = false,
  severity_sort = true,
  signs = {
    text = {
      [sev.ERROR] = "⛔",
      [sev.WARN]  = "⚠️",
      [sev.HINT]  = "💡",
      [sev.INFO]  = "⚠️",
    },
  },
})

