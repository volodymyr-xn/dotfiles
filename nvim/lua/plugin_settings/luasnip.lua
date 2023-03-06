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
require("luasnip.loaders.from_snipmate").lazy_load()

-- press <Tab> to expand or jump in a snippet. These can also be mapped separately
vim.cmd [[ imap <silent><expr> <C-k> luasnip#expand_or_jumpable() ? '<Plug>luasnip-expand-or-jump' : '<C-k>']]
vim.cmd [[ imap <silent><expr> <C-n> luasnip#expand_or_jumpable() ? '<Plug>luasnip-expand-or-jump' : '']]

-- -1 for jumping backwards.
vim.cmd [[ inoremap <silent> <S-Tab> <cmd>lua require'luasnip'.jump(-1)<Cr> ]]

vim.cmd [[ snoremap <silent> <Tab> <cmd>lua require('luasnip').jump(1)<Cr> ]]
vim.cmd [[ snoremap <silent> <S-Tab> <cmd>lua require('luasnip').jump(-1)<Cr> ]]


-- " For changing choices in choiceNodes (not strictly necessary for a basic setup).
-- imap <silent><expr> <C-E> luasnip#choice_active() ? '<Plug>luasnip-next-choice' : '<C-E>'
-- smap <silent><expr> <C-E> luasnip#choice_active() ? '<Plug>luasnip-next-choice' : '<C-E>'
-- ========================= Helper for vim snippets =======================
-- vim.cmd [[
--   fun! Current_Filename(...)
--     let template = get(a:000, 0, "$1")
--     let arg2 = get(a:000, 1, "")
--
--     let basename = expand('%:t:r')
--
--     if basename == ''
--       return arg2
--     else
--       return substitute(template, '$1', basename, 'g')
--     endif
--   endf
-- ]]