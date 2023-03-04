-- require("plugins/fzf")
-- require("plugins/nvim_tree")
require("plugins/neo_tree")
require("plugins/lualine")
require("plugins/telescope")
require("plugins/nvim_devicons")
require("plugins/vim_rails")
require("plugins/emmet")
require('plugins/ack')
require('plugins/ctags')
-- require('plugins/luasnip')
require('plugins/nvim_snippy')
require('plugins/splitjoin')
require('plugins/vim_illuminate')
require('plugins/vim_test')
require('plugins/vim_markdown')
require('plugins/fugitive')
require('plugins/ale')


-- -- ===================== vim-jsx ====================================
-- -- default 0
-- vim.g.vim_jsx_pretty_colorful_config = 1
--
-- -- vim-jsx
-- -- By default, JSX syntax highlighting and indenting will be enabled only for
-- -- files with the .jsx extension. If you would like JSX in .js files, add
-- vim.g.jsx_ext_required = 0

vim.cmd [[
  function! LighlineTabFilenameWithParentDir(n) abort
    let buflist = tabpagebuflist(a:n)
    let winnr = tabpagewinnr(a:n)
    let bufnum = buflist[winnr - 1]
    let bufname = expand('#'.bufnum.':t')
    let buffullname = expand('#'.bufnum.':a')
    " let buffullname = expand('#')
    " return buffullname
    " return substitute(buffullname, '.*/\([^/]\+/\)', '\1', '')
    if strlen(bufname)
      return substitute(buffullname, '.*/\([^/]\+/\)', '\1', '')
    else
      return strlen(bufname) ? bufname : '[No Name]'
    endif
  endfunction
]]
-- ====================== Vim highlight tag settings ======================
vim.cmd('highlight link matchTagError Todo')
vim.g.vim_matchtag_highlight_cursor_on = 1
