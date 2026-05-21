-- Ack lazy-loader — defers requiring `my_plugins.ack` (~320 LOC) until the
-- user actually runs one of its commands. Each stub below performs the
-- real setup on first invocation, which re-registers the command with the
-- real handler; we then re-dispatch via `vim.cmd(...)` so the user's call
-- is honored on the same keystroke.
--
-- Cmdline keymaps stay registered here (they're just `:Ack...` shortcuts
-- typed into the command line and don't require the module to be loaded).

local ack_opts = {
  ackprg = 'ag --vimgrep',
  highlight = false,
  autoclose = false,
  use_cword_for_empty_search = true,
}

-- 10 commands registered by the real ack.setup(). Each tuple is
-- { name, complete } — all share nargs='*' and bang=true.
local commands = {
  { "Ack",           "file" },
  { "AckAdd",        "file" },
  { "AckFromSearch", "file" },
  { "LAck",          "file" },
  { "LAckAdd",       "file" },
  { "AckFile",       "file" },
  { "AckHelp",       "help" },
  { "LAckHelp",      "help" },
  { "AckWindow",     nil },
  { "LAckWindow",    nil },
}

local loaded = false

-- Idempotent first-call load: runs the real setup which overrides the
-- stubs below with the real handlers.
local function ensure_loaded()
  if loaded then
    return
  end

  loaded = true
  require('my_plugins.ack').setup(ack_opts)
end

for _, def in ipairs(commands) do
  local name, complete = def[1], def[2]
  local cmd_opts = { nargs = "*", bang = true }

  if complete then
    cmd_opts.complete = complete
  end

  vim.api.nvim_create_user_command(name, function(o)
    ensure_loaded()
    local bang = o.bang and "!" or ""
    local args = o.args or ""
    vim.cmd(name .. bang .. " " .. args)
  end, cmd_opts)
end

vim.api.nvim_set_keymap('n', '!', ':Ack<SPACE>', {})
vim.api.nvim_set_keymap('n', '@', '*N:Ack <C-R><C-W><CR>', {})
vim.api.nvim_set_keymap('n', '<leader>]', ':cn<CR>', {})
vim.api.nvim_set_keymap('n', '<leader>[', ':cp<CR>', {})
