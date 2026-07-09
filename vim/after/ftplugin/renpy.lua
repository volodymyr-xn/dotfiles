-- Ren'Py convention is 4-space indentation (this config's global default is 2).
vim.bo.shiftwidth = 4
vim.bo.tabstop = 4
vim.bo.softtabstop = 4
vim.bo.expandtab = true

-- Activate the plugin's official-convention indent rules for renpy buffers
-- only. Global `filetype indent on` is intentionally OFF (general_settings.lua
-- uses `filetype plugin on`), so the indent file is sourced here instead of
-- globally. `runtime!` is a no-op if the plugin ships no indent/renpy.vim.
vim.cmd("runtime! indent/renpy.vim")

-- Ren'Py blocks (label/menu/screen/python) are indentation-delimited, so fold
-- by indent for `za` navigation in long scripts. `foldenable` stays off
-- globally, so nothing folds until asked.
vim.wo.foldmethod = "indent"

-- Run / lint the current Ren'Py project in a Vimux pane (SDK + root auto-detected).
local renpy = require("my_plugins.renpy_tools")

vim.api.nvim_buf_create_user_command(0, "RenpyRun", renpy.run, { desc = "Run Ren'Py project" })
vim.api.nvim_buf_create_user_command(0, "RenpyLint", renpy.lint, { desc = "Lint Ren'Py project" })

-- <localleader>r = run, <localleader>l = lint (buffer-local, localleader is `,`).
vim.keymap.set("n", "<localleader>r", renpy.run, { buffer = true, desc = "Ren'Py: run project" })
vim.keymap.set("n", "<localleader>l", renpy.lint, { buffer = true, desc = "Ren'Py: lint project" })
