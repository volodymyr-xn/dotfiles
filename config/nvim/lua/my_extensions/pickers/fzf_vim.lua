local M = {}

local setup_done = false

function M.setup()
  if setup_done then return end
  setup_done = true

  vim.cmd([[
    command! -bang -nargs=? -complete=dir SearchChangedFilesFZF
          \ call fzf#vim#gitfiles("?", { 'window': { 'height': 0.84, 'width': 1 }, 'options': ['--info=inline'] }, <bang>0)

    function! s:fzf_neighbouring_files()
      let current_file = expand("%")
      let cwd = fnamemodify(current_file, ':h')
      let command = 'ag -g "" -f ' . cwd . ' --depth 0'
      call fzf#run({
            \ 'source': command,
            \ 'sink':   'e',
            \ 'options': ['-m', '-x', '+s', '--info=inline', '--preview', '~/.vim/plugged/fzf.vim/bin/preview.sh {}'],
            \ 'window':  { 'height': 0.96, 'width': 1 } })
    endfunction

    command! FuzzySearchSiblingFilesInCurrentDir call s:fzf_neighbouring_files()

    command! -nargs=1 FuzzySearchFileInDir FZF <args>

    function! s:ag_to_qf(line)
      let parts = split(a:line, ':')
      return {'filename': parts[0], 'lnum': parts[1], 'col': parts[2],
            \ 'text': join(parts[3:], ':')}
    endfunction

    function! s:ag_handler(lines)
      if len(a:lines) < 2 | return | endif
      let cmd = get({'ctrl-x': 'split', 'ctrl-v': 'vertical split', 'ctrl-t': 'tabe'}, a:lines[0], 'e')
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

    command! -nargs=* CustomFullTextSearch call fzf#run({
          \ 'source':  printf('ag --nogroup --column --color "%s"',
          \                   escape(empty(<q-args>) ? '^(?=.)' : <q-args>, '"\')),
          \ 'sink*':    function('<sid>ag_handler'),
          \ 'options': '--ansi --expect=ctrl-t,ctrl-v,ctrl-x --delimiter : --nth 4.. '.
          \            '--multi --bind=ctrl-a:select-all,ctrl-d:deselect-all '.
          \            '--color hl:68,hl+:110',
          \ 'down':    '50%'
          \ })
  ]])
end

function M.find_files()
  vim.cmd("FZF")
end

function M.find_sibling_files()
  vim.cmd("FuzzySearchSiblingFilesInCurrentDir")
end

function M.find_changed_files()
  local current_buf = vim.api.nvim_get_current_buf()
  if vim.b[current_buf].is_onediff_buffer then
    local onediff = require("my_extensions.onediff")
    onediff.open_file_picker()
  else
    vim.cmd("SearchChangedFilesFZF")
  end
end

function M.find_changed_files_by_extension(extension)
  local git_cmd = vim.fn.systemlist("git status --porcelain")
  local files = {}
  for _, line in ipairs(git_cmd) do
    local file = line:sub(4)
    if file:match(extension .. "$") then
      table.insert(files, file)
    end
  end

  if #files == 0 then
    vim.notify("No changed files matching: " .. extension, vim.log.levels.INFO)
    return
  end

  vim.fn["fzf#run"]({
    source = files,
    sink = "e",
    options = { "--prompt", "Git Status (" .. extension .. ")> " },
    window = { height = 0.84, width = 1 },
  })
end

function M.find_resource_in_dir(dir)
  vim.cmd("FuzzySearchFileInDir " .. vim.fn.fnameescape(dir))
end

function M.find_files_in_dirs_relative(dirs)
  local available = vim.tbl_filter(function(d) return d and d ~= "" and vim.fn.isdirectory(d) == 1 end, dirs)
  if #available == 0 then return end
  local entries = {}
  for _, dir in ipairs(available) do
    for _, full_path in ipairs(vim.fn.systemlist("fd --type f . " .. dir)) do
      local relative = full_path:gsub("^" .. vim.pesc(dir) .. "/", "")
      table.insert(entries, relative .. "\t" .. full_path)
    end
  end
  vim.fn["fzf#run"]({
    source = entries,
    options = { "--with-nth=1", "--delimiter=\t", "--layout=default" },
    sink = function(selected)
      local full_path = selected:match("\t(.+)$")
      if full_path then vim.cmd("edit " .. vim.fn.fnameescape(full_path)) end
    end,
    window = { height = 0.84, width = 1 },
  })
end

function M.find_files_in_dirs(dirs)
  local available = vim.tbl_filter(function(d) return d and d ~= "" and vim.fn.isdirectory(d) == 1 end, dirs)
  if #available == 0 then return end
  vim.fn["fzf#run"]({
    source = "fd --type f . " .. table.concat(available, " "),
    sink = "e",
    window = { height = 0.84, width = 1 },
  })
end

function M.buffer_fuzzy_find()
  vim.cmd("BLines")
end

function M.buffer_list()
  vim.cmd("Buffers")
end

function M.live_grep()
  vim.cmd("Ag!")
end

function M.custom_full_text_search()
  vim.cmd("CustomFullTextSearch")
end

function M.open_picker_menu()
  vim.cmd("FZF")
end

return M
