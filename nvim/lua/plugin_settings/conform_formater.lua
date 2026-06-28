-- Formatting via conform.nvim.
--
-- Format-on-save is OFF by default and opted into PER PROJEKT. Enable it from a
-- projekt's `.nvim.lua` (loaded via exrc, see general_settings.lua:40) with:
--     vim.g.enable_format_on_save = true
-- then run `:trust` once in that projekt root so exrc is allowed to source it.
--
-- `:Format` (manual, always works) and `:FormatToggle` / `:FormatEnable` /
-- `:FormatDisable` (runtime overrides) work regardless of the per-projekt flag.

local conform = require("conform")
local conform_util = require("conform.util")

conform.setup({
  formatters_by_ft = {
    ruby = { "rubocop" },
    eruby = { "herb" },
    javascript = { "prettierd", "prettier", stop_after_first = true },
    typescript = { "prettierd", "prettier", stop_after_first = true },
    javascriptreact = { "prettierd", "prettier", stop_after_first = true },
    typescriptreact = { "prettierd", "prettier", stop_after_first = true },
    json = { "prettierd", "prettier", stop_after_first = true },
    yaml = { "yamlfix" },
  },
  formatters = {
    -- ERB via the projekt's Herb toolchain. `herb format -` reads stdin and
    -- writes ONLY the formatted template to stdout (diagnostics go to stderr),
    -- and honours the projekt's .herb.yml (indent, max line length,
    -- tailwind-class-sorter). Running from the projekt root lets the `herb`
    -- gem delegate to the local node_modules/.bin/herb-format and find
    -- .herb.yml.
    herb = {
      command = "herb",
      args = { "format", "-" },
      stdin = true,
      cwd = conform_util.root_file({ ".herb.yml", "Gemfile", ".git" }),
    },
  },
  format_on_save = function(bufnr)
    -- Opt-in per projekt via vim.g.enable_format_on_save (set in .nvim.lua).
    -- A buffer-local vim.b.enable_format_on_save overrides the global, either
    -- way (e.g. force-off a single buffer in an otherwise-enabled projekt).
    local enabled = vim.b[bufnr].enable_format_on_save
    if enabled == nil then
      enabled = vim.g.enable_format_on_save
    end

    if not enabled then
      return
    end

    return { timeout_ms = 3000, lsp_format = "fallback" }
  end,
})

vim.api.nvim_create_user_command("Format", function(args)
  local range = nil
  if args.count ~= -1 then
    local end_line = vim.api.nvim_buf_get_lines(0, args.line2 - 1, args.line2, true)[1]
    range = {
      start = { args.line1, 0 },
      ["end"] = { args.line2, end_line:len() },
    }
  end
  require("conform").format({ async = true, lsp_format = "fallback", range = range })
end, { range = true })

vim.api.nvim_create_user_command("FormatEnable", function()
  vim.g.enable_format_on_save = true
  vim.notify("conform: format-on-save ON (global)", vim.log.levels.INFO)
end, {})

vim.api.nvim_create_user_command("FormatDisable", function()
  vim.g.enable_format_on_save = false
  vim.notify("conform: format-on-save OFF (global)", vim.log.levels.INFO)
end, {})

vim.api.nvim_create_user_command("FormatToggle", function()
  vim.g.enable_format_on_save = not vim.g.enable_format_on_save
  local state = vim.g.enable_format_on_save and "ON" or "OFF"
  vim.notify("conform: format-on-save " .. state .. " (global)", vim.log.levels.INFO)
end, {})

-- vim.keymap.set('n', '<Leader>`', ':Format<CR>', {})
