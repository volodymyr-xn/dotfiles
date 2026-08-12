-- Options for ack.nvim (nvim/plugins/ack.nvim). Loaded by lazy on the
-- first :Ack* command; the commands themselves come from the plugin.
require("ack").setup({
  -- rg emits one entry per matching line (no quickfix duplicates when a
  -- line matches multiple times); ag's --vimgrep is the only ag mode with
  -- per-line filenames but emits one entry per match. Swap here to switch:
  -- search_command = 'ag --vimgrep',
  search_command = "rg --column --no-heading --with-filename --color never --follow",
  highlight = false,
  autoclose = false,
  use_cword_for_empty_search = true,
  -- remove_duplicates is auto-detected from search_command (on for `--vimgrep`, off
  -- for the per-line rg above); set it here to override.
})
