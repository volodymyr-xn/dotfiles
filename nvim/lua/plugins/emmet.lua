-- ===================== Emmet settings  ====================================
-- Expand html tag by Emmet
-- vim.api.nvim_set_keymap("i", "<C-j>", "<C-y>,", {noremap = true, silent = true})
vim.api.nvim_set_keymap("i", "<C-l>", "<C-y>,", {noremap = true, silent = true})

-- vim.api.nvim_set_keymap("i", "<expr>k<tab>", 'emmet#expandAbbrIntelligent("\\<tab>")', {noremap = true, silent = true})
vim.g.user_emmet_settings = {
  ['javascript.jsx'] = {
    ['extends'] = 'jsx',
  },
}

