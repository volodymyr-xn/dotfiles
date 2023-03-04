-- ==============================================================================
-- ================== Snippets mappings =========================================
-- ==============================================================================

-- Snipmate go to previos stop point in snippet
-- vim.api.nvim_set_keymap('i', '<C-o>', '<C-R>=snipMate#BackwardsSnippet()<CR>', {noremap=true})
-- vim.api.nvim_set_keymap('v', '<C-o>', ':call snipMate#BackwardsSnippet()<CR>', {noremap=true})
-- vim.api.nvim_set_keymap('s', '<C-o>', '<Esc>a<C-R>=snipMate#BackwardsSnippet()<CR>', {noremap=true})
--
-- -- Snipmate expand snippet
-- vim.api.nvim_set_keymap('i', '<silent><C-k>', '<C-R>=snipMate#TriggerSnippet()<CR>', {noremap=true})
-- vim.api.nvim_set_keymap('s', '<C-k>', ':call snipMate#TriggerSnippet()<CR>', {noremap=true})
-- vim.api.nvim_set_keymap('s', '<silent><C-k>', '<Esc>a<C-R>=snipMate#TriggerSnippet()<CR>', {noremap=true})

-- press <Tab> to expand or jump in a snippet. These can also be mapped separately
vim.cmd [[ imap <silent><expr> <C-k> luasnip#expand_or_jumpable() ? '<Plug>luasnip-expand-or-jump' : '<C-k>']]

-- -1 for jumping backwards.
vim.cmd [[ inoremap <silent> <S-Tab> <cmd>lua require'luasnip'.jump(-1)<Cr> ]]

vim.cmd [[ snoremap <silent> <Tab> <cmd>lua require('luasnip').jump(1)<Cr> ]]
vim.cmd [[ snoremap <silent> <S-Tab> <cmd>lua require('luasnip').jump(-1)<Cr> ]]

require("luasnip.loaders.from_snipmate").lazy_load()

-- " For changing choices in choiceNodes (not strictly necessary for a basic setup).
-- imap <silent><expr> <C-E> luasnip#choice_active() ? '<Plug>luasnip-next-choice' : '<C-E>'
-- smap <silent><expr> <C-E> luasnip#choice_active() ? '<Plug>luasnip-next-choice' : '<C-E>'
