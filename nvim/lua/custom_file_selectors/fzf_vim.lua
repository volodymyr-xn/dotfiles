local M = {}

local root = require("custom_file_selectors.root")

local setup_done = false

function M.setup()
  if setup_done then return end
  setup_done = true

  vim.cmd([[
    function! s:fzf_line_handler(l)
      let keys = split(a:l, ':\t')
      exec 'buf' keys[0]
      exec keys[1]
      normal! ^zz
    endfunction

    function! s:fzf_buffer_lines()
      let res = []
      for b in filter(range(1, bufnr('$')), 'buflisted(v:val)')
        call extend(res, map(getbufline(b,0,"$"), 'b . ":\t" . (v:key + 1) . ":\t" . v:val '))
      endfor
      return res
    endfunction

    command! FZFLines call fzf#run({
    \   'source':  <sid>fzf_buffer_lines(),
    \   'sink':    function('<sid>fzf_line_handler'),
    \   'options': '--extended --nth=3..',
    \   'down':    '60%'
    \})

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
  ]])

  local function ag_to_qf(line)
    local parts = vim.split(line, ":")
    return {
      filename = parts[1],
      lnum = parts[2],
      col = parts[3],
      text = table.concat(parts, ":", 4),
    }
  end

  local function ag_handler(lines)
    if #lines < 2 then return end

    local key = lines[1]
    local list = vim.tbl_map(ag_to_qf, vim.list_slice(lines, 2))

    -- ctrl-q: force the whole selection into quickfix and focus its first item
    -- inside the quickfix window (copen focuses that window; cursor to line 1).
    if key == "ctrl-q" then
      vim.fn.setqflist(list)
      vim.cmd("copen")
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      return
    end

    local cmd_map = {
      ["ctrl-x"] = "split",
      ["ctrl-v"] = "vertical split",
      ["ctrl-t"] = "tabe"
    }
    local cmd = cmd_map[key] or "e"
    local first = list[1]
    vim.cmd(cmd .. " " .. vim.fn.escape(first.filename, " %#\\"))
    vim.cmd(tostring(first.lnum))
    vim.cmd("normal! " .. first.col .. "|zz")

    if #list > 1 then
      vim.fn.setqflist(list)
      vim.cmd("copen | wincmd p")
    end
  end

  -- Shared fzf options for the full-text searches; ctrl-q sends the selection
  -- to the quickfix list (see ag_handler), Tab/ctrl-a/ctrl-d multi-select.
  local SEARCH_OPTIONS = "--ansi --expect=ctrl-t,ctrl-v,ctrl-x,ctrl-q --delimiter : --nth 4.. "
    .. "--multi --bind=ctrl-a:select-all,ctrl-d:deselect-all "
    .. "--color hl:68,hl+:110"

  -- --follow: makes ag follow symlinks when searching
  vim.api.nvim_create_user_command("CustomFullTextSearch", function(opts)
    local query = opts.args ~= "" and opts.args or "^(?=.)"
    vim.fn["fzf#run"]({
      source = string.format('ag --nogroup --column --color --follow "%s"', query),
      ["sink*"] = ag_handler,
      options = SEARCH_OPTIONS,
      down = "50%",
    })
  end, { nargs = "*" })

  local RG_CMD = "rg --column --line-number --no-heading --color=always --smart-case --max-columns=500"

  vim.api.nvim_create_user_command("CustomFullTextSearchRg", function(opts)
    local query = opts.args ~= "" and opts.args or "."
    vim.fn["fzf#run"]({
      source = RG_CMD .. " " .. vim.fn.shellescape(query),
      ["sink*"] = ag_handler,
      options = SEARCH_OPTIONS,
      down = "50%",
    })
  end, { nargs = "*" })
end

function M.find_files()
  vim.cmd("FZF " .. vim.fn.fnameescape(root.get()))
end

function M.find_sibling_files()
  vim.cmd("FuzzySearchSiblingFilesInCurrentDir")
end

function M.find_changed_files()
  local current_buf = vim.api.nvim_get_current_buf()
  if vim.b[current_buf].is_onediff_buffer then
    local onediff = require("my_plugins.onediff")
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
  local title = vim.fn.fnamemodify(dir, ":t")
  vim.fn["fzf#run"](vim.fn["fzf#wrap"]({
    source = "fd --type f . " .. vim.fn.fnameescape(dir),
    options = { "--prompt", title .. "> " },
    window = { height = 0.84, width = 1 },
  }))
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

function M.oldfiles()
  local cwd = vim.fn.getcwd() .. "/"
  local seen = {}
  local files = {}

  local function add(path)
    if seen[path] or not vim.startswith(path, cwd) or vim.fn.filereadable(path) ~= 1 then return end
    seen[path] = true
    table.insert(files, path:sub(#cwd + 1))
  end

  for buf = 1, vim.fn.bufnr("$") do
    if vim.fn.buflisted(buf) == 1 then
      local name = vim.fn.bufname(buf)
      if name ~= "" then add(name) end
    end
  end

  for _, f in ipairs(vim.v.oldfiles) do
    if not f:match("fugitive:") and not f:match("NERD_tree")
        and not f:match("^/tmp/") and not f:match("%.git/") then
      add(f)
    end
  end

  if #files == 0 then return end

  vim.fn["fzf#run"]({
    source = vim.fn.reverse(files),
    sink = "edit",
    options = { "-m", "-x", "+s", "--prompt", "MRU> " },
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

function M.live_grep_in_dirs(dirs)
  local available = vim.tbl_filter(function(d) return d and d ~= "" and vim.fn.isdirectory(d) == 1 end, dirs)
  if #available == 0 then return end
  local dirs_str = table.concat(vim.tbl_map(vim.fn.shellescape, available), " ")
  local title = table.concat(available, ", ")
  vim.fn["fzf#vim#grep"](
    "rg --column --line-number --no-heading --color=always --smart-case . " .. dirs_str,
    1,
    vim.fn["fzf#vim#with_preview"]({ options = { "--prompt", title .. "> " } }),
    0
  )
end

function M.custom_full_text_search()
  vim.cmd("CustomFullTextSearch")
end

function M.custom_full_text_search_rg()
  vim.cmd("CustomFullTextSearchRg")
end

-- Like live_grep (Ag) but with a bat-backed preview window via fzf#vim#with_preview.
-- match:none stops the catch-all `.` pattern from highlighting every line; fzf
-- highlights the typed query instead.
function M.live_grep_with_preview()
  vim.fn["fzf#vim#grep"](
    "rg --column --line-number --no-heading --color=always --smart-case --colors 'match:none' .",
    1,
    vim.fn["fzf#vim#with_preview"]({ options = { "--prompt", "Live Grep (preview)> " } }),
    0
  )
end

-- Like custom_full_text_search (--follow symlinks) but with a bat-backed preview window
function M.custom_full_text_search_with_preview()
  vim.fn["fzf#vim#grep"](
    "rg --column --line-number --no-heading --color=always --smart-case --follow --colors 'match:none' .",
    1,
    vim.fn["fzf#vim#with_preview"]({ options = { "--prompt", "Full Text (preview)> " } }),
    0
  )
end

function M.live_grep_changed_files()
  local lines = vim.fn.systemlist("git diff --name-only --diff-filter=ACMR HEAD && git ls-files --others --exclude-standard")
  local files = vim.tbl_filter(function(f) return f ~= "" and vim.fn.filereadable(f) == 1 end, lines)
  if #files == 0 then
    vim.notify("No changed/added files", vim.log.levels.INFO)
    return
  end
  local file_args = table.concat(vim.tbl_map(vim.fn.shellescape, files), " ")
  vim.fn["fzf#vim#grep"](
    "rg --column --line-number --no-heading --color=always --smart-case . " .. file_args,
    1,
    vim.fn["fzf#vim#with_preview"]({ options = { "--prompt", "Changed Files> " } }),
    0
  )
end

function M.search_lines_in_all_buffers()
  vim.cmd("FZFLines")
end

function M.open_picker_menu()
  vim.cmd("FZF")
end

return M
