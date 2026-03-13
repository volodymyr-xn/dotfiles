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
