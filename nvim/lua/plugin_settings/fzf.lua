-- =========================================================================
-- ====================== FZF settings =====================================
-- =========================================================================
vim.o.rtp = vim.o.rtp .. ',~/.fzf'

vim.g.fzf_layout = { window = { width = 1, height = 0.8 } }
vim.g.fzf_colors = {
  fg = {'fg', 'Normal'},
  bg = {'bg', 'Normal'},
  hl = {'fg', 'Conditional'},
  ['fg+'] = {'fg', 'CursorLine', 'CursorColumn', 'Normal'},
  ['bg+'] = {'bg', 'CursorLine', 'CursorColumn'},
  ['hl+'] = {'fg', 'Conditional'},
  info = {'fg', 'PreProc'},
  border = {'fg', 'Ignore'},
  prompt = {'fg', 'Conditional'},
  pointer = {'fg', 'Exception'},
  marker = {'fg', 'Statement'},
  spinner = {'fg', 'Label'},
  header = {'fg', 'Comment'}
}

-- ctrl-q on the built-in commands (:Files, :Rg, :Buffers, …): send the
-- Tab-selected items to the quickfix list. ctrl-t/x/v open in tab/split.
vim.cmd([[
  function! s:build_quickfix_list(lines)
    call setqflist(map(copy(a:lines), '{ "filename": v:val, "lnum": 1 }'))
    copen
    1
  endfunction

  let g:fzf_action = {
    \ 'ctrl-q': function('s:build_quickfix_list'),
    \ 'ctrl-t': 'tab split',
    \ 'ctrl-x': 'split',
    \ 'ctrl-v': 'vsplit' }
]])
