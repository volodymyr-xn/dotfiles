-- =========================================================================
-- ====================== FZF settings =====================================
-- =========================================================================
vim.o.rtp = vim.o.rtp .. ',~/.fzf'

-- Tab marks the item in place (default tab is toggle+down). Set on the env
-- inside nvim so it applies regardless of the shell's FZF_DEFAULT_OPTS; guarded
-- so re-sourcing this file doesn't append the bind twice. Theme colors
-- (including the selected-row highlight) live in the shell's FZF_DEFAULT_OPTS.
local fzf_opts = vim.env.FZF_DEFAULT_OPTS or ""
if not fzf_opts:find("tab:toggle", 1, true) then
  vim.env.FZF_DEFAULT_OPTS = fzf_opts .. " --bind tab:toggle,shift-tab:toggle"
end

vim.g.fzf_layout = { window = { width = 1, height = 0.8 } }

-- alt-p toggles the preview window across all fzf.vim previewers (:Files, :Rg,
-- live_grep_with_preview, custom_full_text_search_with_preview, …). First list
-- item is the default layout, second is the toggle key.
vim.g.fzf_preview_window = { 'right:50%', 'alt-p' }

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
