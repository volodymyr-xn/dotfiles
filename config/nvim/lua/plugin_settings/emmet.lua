-- ===================== Emmet settings  ====================================
-- Expand html tag by Emmet
vim.api.nvim_set_keymap("i", "<C-l>", "<c-y>,", { desc = "Expand Emmet abbreviation" })

-- vim.api.nvim_set_keymap("i", "<expr>k<tab>", 'emmet#expandAbbrIntelligent("\\<tab>")', {noremap = true, silent = true})
vim.g.user_emmet_settings = {
  ['javascript.jsx'] = {
    ['extends'] = 'jsx',
  },
}

-- vim.keymap.set(
--  { "n", "v" },
--  '<leader>z',
--  -- require('nvim-emmet').wrap_with_abbreviation
-- )
