-- Save current buffer
vim.api.nvim_set_keymap('n', '<Leader>w', ':w<CR>', { silent = true, noremap = true, desc = "Save current file" })

-- Re-source the entire Neovim config (with bytecode cache wipe).
-- `:Reload` is defined in `commands.lua` — it clears `vim.loader`'s luac
-- entries for user-config paths first, so a fix never gets shadowed by
-- stale bytecode (the root cause of the recurring git_diff_popup bug).
vim.api.nvim_set_keymap('n', '<Leader>vr', ':Reload<CR>', { noremap = true, desc = "Reload vim config" })

-- Alternate/related file navigation (vim-projectionist)
vim.api.nvim_set_keymap('n', 'sa', ':A<CR>', { noremap = true, desc = "Go to alternate file" })
vim.api.nvim_set_keymap('n', 'sr', ':R<CR>', { noremap = true, desc = "Go to related file" })

-- Copy relative path of current file to system clipboard
vim.api.nvim_set_keymap('n', '`', ':CopyCurrentFileRelativePathToClipboard<CR>', { noremap = true, desc = "Copy file path to clipboard" })

-- Custom highlight group: green color for reloaded filenames in echo message
-- vim.api.nvim_set_hl(0, "ReloadedFilename", { fg = "#00ff00", bold = true })
vim.api.nvim_set_hl(0, "ReloadedFilename", { fg = "#a6e3a1", bold = true })

-- Reload file from disk with a brief status echo, highlighting the file name in green
local function reload_file_with_message()
  -- Skip [No Name] buffers; :edit! errors with E32 when there's no file on disk
  if vim.api.nvim_buf_get_name(0) == '' then
    vim.api.nvim_echo({ { "No file to reload", "WarningMsg" } }, false, {})
    return
  end

  vim.cmd('edit!')
  local filename = vim.fn.expand('%:t')
  vim.api.nvim_echo({
    { "File reloaded ", "MoreMsg" },
    { filename,        "ReloadedFilename" },
  }, false, {})
  vim.defer_fn(function()
    vim.api.nvim_echo({ { "" } }, false, {})
  end, 1000)
end

-- Reload current file from disk (OneDiff buffers have their own buffer-local <Leader>e)
vim.keymap.set('n', '<Leader>e', reload_file_with_message, { noremap = true, silent = true, desc = "Reload file" })

-- Ruby ViewComponent: navigate to specific file type in the same component
vim.api.nvim_set_keymap('n', 's1', '<cmd>lua require("my_plugins.ruby_component_toggle").navigate_to_extension(".rb")<CR>',
  { noremap = true, silent = true, desc = "Navigate to .rb file" })
vim.api.nvim_set_keymap('n', 's2', '<cmd>lua require("my_plugins.ruby_component_toggle").navigate_to_extension(".html.erb")<CR>',
  { noremap = true, silent = true, desc = "Navigate to .html.erb file" })
vim.api.nvim_set_keymap('n', 's3', '<cmd>lua require("my_plugins.ruby_component_toggle").navigate_to_style()<CR>',
  { noremap = true, silent = true, desc = "Navigate to .scss/.css file" })
vim.api.nvim_set_keymap('n', 's4', '<cmd>lua require("my_plugins.ruby_component_toggle").navigate_to_extension(".js")<CR>',
  { noremap = true, silent = true, desc = "Navigate to .js file" })
-- Toggle between .rb and .html.erb for Ruby view components
vim.keymap.set('n', 'gr', function() require('my_plugins.ruby_component_toggle').toggle_alternate() end,
  { noremap = true, silent = true, desc = "Toggle between .rb and .html.erb" })

-- Neo-tree: defined here (not inside plugin_settings/neo_tree.lua) so that
-- the keymaps exist at startup. Pressing them dispatches :Neotree, which
-- triggers neo-tree's `cmd` lazy-load. Plugin config still applies via the
-- spec's `config = function()` callback the first time the cmd runs.

-- Disable default Ctrl-Backslash so Vim does not eat the keystroke before
-- our mapping resolves.
vim.api.nvim_set_keymap("n", "<C-\\>", "<NOP>", { noremap = true, silent = true })

-- Toggle sidebar: route to onediff in onediff buffers, otherwise Neotree.
vim.keymap.set("n", "<C-\\>", function()
  local current_buf = vim.api.nvim_get_current_buf()

  if vim.b[current_buf].is_onediff_buffer or vim.b[current_buf].onediff_instance_id then
    local ok, onediff = pcall(require, "my_plugins.onediff")
    if ok then
      onediff.toggle_sidebar()
      return
    end
  end

  vim.cmd("Neotree toggle")
end, { noremap = true, silent = true, desc = "Toggle sidebar" })

-- reveal_force_cwd: if file is outside cwd, silently change cwd to its
-- directory instead of prompting "Change cwd to …? [Y]es, (N)o".
vim.api.nvim_set_keymap("n", "<Leader>0", ":Neotree filesystem reveal_force_cwd<CR>",
  { noremap = true, silent = false, desc = "Reveal file in neo-tree" })

-- Open current file in default app; HTML/HTM files open in Chrome with the "1 Work" profile
vim.keymap.set('n', 'sn', function()
  local filepath = vim.fn.expand('%:p')
  local ext = vim.fn.expand('%:e')
  if ext == 'html' or ext == 'htm' then
    vim.fn.jobstart({ 'c-open-work-chrome', filepath }, { detach = true })
  else
    vim.fn.jobstart({ 'open', filepath }, { detach = true })
  end
end, { noremap = true, silent = true, desc = "Open file in default application" })
