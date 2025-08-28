-- =========================================================================
-- ====================== FZF settings =====================================
-- =========================================================================
-- fzf
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

-- function git_changed_files()
--   vim.fn['fzf#run']({
--     source = 'git diff --name-only --cached && git diff --name-only',
--     sink = 'e',
--     options = '--prompt "Changed Files> " --preview "git diff --color=always {1} | less -R"'
--   })
-- end

vim.cmd [[
  command! -bang -nargs=? -complete=dir SearchChangedFilesFZF
        \ call fzf#vim#gitfiles("?", { 'window': { 'height': 0.7, 'width': 1 },  'options': ['--info=inline' ]},  <bang>0)
]]

vim.api.nvim_set_keymap('n', 'q', ':SearchChangedFilesFZF()<CR>', { noremap = true, silent = true })

-- To learn more about preview window options, see `--preview-window` section of `man fzf`.
-- vim.g.fzf_preview_window = {'up:52%', 'ctrl-/'}
--
-- Custom full text search by FZF and AG(no preview window)
vim.api.nvim_set_keymap('n', '<Leader>p', ':CustomFullTextSearch<CR>', { noremap = true })

-- Custom full text search by FZF and AG(no preview window)
-- fzf.vim Full text search in fullscreen by AG(with preview window)
-- "!" indicates for FZF that FZf should be opened in fullscreen
vim.api.nvim_set_keymap('n', '<Leader>o', ':Ag!<CR>', { noremap = true })

-- local components_dir = CustomFindFirstAvailableDir({'app/components', "app/view_components"})

-- if (components_dir) then
--   vim.api.nvim_set_keymap('n', '<Leader>f', ':FuzzySearchFileInDir ' .. components_dir .. '<CR>', {})
-- end

vim.cmd [[
command! -bang -nargs=? -complete=dir Files
      \ call fzf#vim#files(<q-args>, { 'window': { 'height': 1, 'width': 1 }, 'options': ['--info=inline', '--preview', '~/.vim/plugged/fzf.vim/bin/preview.sh {}']}, <bang>0)

" Files fzf command shows preview
command! -nargs=1 FuzzySearchFileInDir FZF <args>

nnoremap <C-p> :FZF<CR>
" nnoremap <C-p> :Files<CR>

"To learn more about preview window options, see `--preview-window` section of `man fzf`.
let g:fzf_preview_window = ['up:52%', 'ctrl-/']

" Search sibling files in same directory as current file(with preview window)
noremap <Leader>i :FuzzySearchSiblingFilesInCurrentDir <CR>

" Search javascripts
noremap <Leader>j :FuzzySearchFileInDir app/assets/javascripts <CR>

" Search app/models by FZF
noremap <Leader>m :FuzzySearchFileInDir app/models<CR>

" Search app/assets/stylesheets by FZF
noremap <Leader>s :FuzzySearchFileInDir app/assets/stylesheets<CR>

" Search app/views by FZF
nnoremap <Leader>d :FuzzySearchFileInDir app/views<CR>

" Search app/components by FZF
" nnoremap <Leader>f :FuzzySearchFileInDir app/components<CR>

" Search app/locales by FZF
nnoremap <Leader>b :FuzzySearchFileInDir config/locales<CR>

" Search app/controllers by FZF
noremap <Leader>c :FuzzySearchFileInDir app/controllers<CR>

function! s:fzf_neighbouring_files()
  let current_file =expand("%")
  " Shows full absolute path
  " let cwd = fnamemodify(current_file, ':p:h')
  " Shows filename and dirname path
  let cwd = fnamemodify(current_file, ':h')
  " let command = 'ag -g "" -f ' . cwd . ' --depth 0'
  let command = 'ag -g "" -f ' . cwd . ' --depth 0'

  call fzf#run({
        \ 'source': command,
        \ 'sink':   'e',
        \ 'options': ['-m', '-x', '+s', '--info=inline', '--preview', '~/.vim/plugged/fzf.vim/bin/preview.sh {}'],
        \ 'window':  { 'height': 0.8 , 'width': 1 } })
endfunction

command! FuzzySearchSiblingFilesInCurrentDir call s:fzf_neighbouring_files()

" Full text search support for FZF
function! s:ag_to_qf(line)
  let parts = split(a:line, ':')
  return {'filename': parts[0], 'lnum': parts[1], 'col': parts[2],
        \ 'text': join(parts[3:], ':')}
endfunction

function! s:ag_handler(lines)
  if len(a:lines) < 2 | return | endif

  let cmd = get({'ctrl-x': 'split',
               \ 'ctrl-v': 'vertical split',
               \ 'ctrl-t': 'tabe'}, a:lines[0], 'e')
  let list = map(a:lines[1:], 's:ag_to_qf(v:val)')

  let first = list[0]
  execute cmd escape(first.filename, ' %#\')
  execute first.lnum
  execute 'normal!' first.col.'|zz'

  if len(list) > 1
    call setqflist(list)
    copen
    wincmd p
  endif
endfunction

" CustomFullTextSearch command does full text search by FZF
command! -nargs=* CustomFullTextSearch call fzf#run({
      \ 'source':  printf('ag --nogroup --column --color "%s"',
      \                   escape(empty(<q-args>) ? '^(?=.)' : <q-args>, '"\')),
      \ 'sink*':    function('<sid>ag_handler'),
      \ 'options': '--ansi --expect=ctrl-t,ctrl-v,ctrl-x --delimiter : --nth 4.. '.
      \            '--multi --bind=ctrl-a:select-all,ctrl-d:deselect-all '.
      \            '--color hl:68,hl+:110',
      \ 'down':    '50%'
      \ })


command! ProjectFiles execute 'Files!' s:find_git_root()

function! s:find_git_root()
  return system('git rev-parse --show-toplevel 2> /dev/null')[:-2]
endfunction
]]
