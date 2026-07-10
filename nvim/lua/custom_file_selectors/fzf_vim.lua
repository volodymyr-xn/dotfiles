-- fzf.vim backend for the pluggable file-selector API. Each M.* function is a
-- picker invoked by the keymaps. Sibling telescope.lua / fzf_lua.lua files
-- expose the same names, so the active backend is swappable.
local M = {}

local root = require("custom_file_selectors.root")

-- Green tint marking full-text/content searches apart from the file finders.
local SEARCH_BORDER_COLOR = "#a6da95"

-- fzf flags that label a picker with a left-aligned title on a border drawn
-- around just the input line, so the label sits directly above the prompt
-- regardless of layout. --list-border boxes the results separately from the
-- input. --input-label-pos 3 offsets the label in from the left corner (0 would
-- center it). --info=inline-right puts the match counter at the right end of the
-- prompt line.
local function label_flags(label)
  return { "--info=inline-right", "--list-border", "--input-border", "--input-label", " " .. label .. " ", "--input-label-pos", "3" }
end

-- Append label_flags for `label` onto an existing fzf options list; returns it.
local function with_label(options, label)
  return vim.list_extend(options, label_flags(label))
end

-- String form of label_flags for pickers that pass --options as one string.
local function label_flags_str(label)
  return string.format(" --info=inline-right --list-border --input-border --input-label ' %s ' --input-label-pos 3", label)
end

-- Full-text/content searches reuse the label flags but tint the input border
-- and its label green, distinguishing them from the file finders.
local SEARCH_COLOR_FLAG = "--color=input-border:" .. SEARCH_BORDER_COLOR .. ",input-label:" .. SEARCH_BORDER_COLOR

local function search_label_flags(label)
  local flags = label_flags(label)
  table.insert(flags, SEARCH_COLOR_FLAG)
  return flags
end

-- String form of search_label_flags.
local function search_label_flags_str(label)
  return label_flags_str(label) .. " " .. SEARCH_COLOR_FLAG
end

-- Picker label built from directory basenames, e.g. "javascript, components".
local function dirs_label(dirs)
  return table.concat(vim.tbl_map(function(dir) return vim.fn.fnamemodify(dir, ":t") end, dirs), ", ")
end

-- Guards M.setup() so the Vimscript commands below are defined only once.
local setup_done = false

-- Define the fzf.vim Vimscript commands and the rg/ag user-commands. Idempotent:
-- safe to call again on every backend switch.
function M.setup()
  if setup_done then return end
  setup_done = true

  vim.cmd([[
    " Open the buffer+line picked from FZFLines and center the cursor.
    function! s:fzf_line_handler(l)
      let keys = split(a:l, ':\t')
      exec 'buf' keys[0]
      exec keys[1]
      normal! ^zz
    endfunction

    " Build "bufnr:<tab>lnum:<tab>text" for every line of every listed buffer.
    function! s:fzf_buffer_lines()
      let res = []
      for b in filter(range(1, bufnr('$')), 'buflisted(v:val)')
        call extend(res, map(getbufline(b,0,"$"), 'b . ":\t" . (v:key + 1) . ":\t" . v:val '))
      endfor
      return res
    endfunction

    " Fuzzy-search every line across all listed buffers (match on text only).
    command! FZFLines call fzf#run({
    \   'source':  <sid>fzf_buffer_lines(),
    \   'sink':    function('<sid>fzf_line_handler'),
    \   'options': '--extended --nth=3.. --info=inline-right --list-border --input-border --input-label " All Buffer Lines (text only) " --input-label-pos 3 --color=input-border:#a6da95,input-label:#a6da95',
    \   'down':    '60%'
    \})

    " fzf over files git reports as modified (gitfiles "?").
    command! -bang -nargs=? -complete=dir SearchChangedFilesFZF
          \ call fzf#vim#gitfiles("?", { 'window': { 'height': 0.84, 'width': 1 }, 'options': ['--info=inline-right', '--list-border', '--input-border', '--input-label', ' Changed Files ', '--input-label-pos', '3'] }, <bang>0)

    " Files sitting next to the current file (same dir, no recursion).
    function! s:fzf_neighbouring_files()
      let current_file = expand("%")
      let cwd = fnamemodify(current_file, ':h')
      let command = 'ag -g "" -f ' . cwd . ' --depth 0'
      call fzf#run({
            \ 'source': command,
            \ 'sink':   'e',
            \ 'options': ['-m', '-x', '+s', '--info=inline-right', '--preview', '~/.vim/plugged/fzf.vim/bin/preview.sh {}', '--list-border', '--input-border', '--input-label', ' Sibling Files ', '--input-label-pos', '3'],
            \ 'window':  { 'height': 0.96, 'width': 1 } })
    endfunction

    command! FuzzySearchSiblingFilesInCurrentDir call s:fzf_neighbouring_files()

    " :FZF scoped to the directory passed as the sole argument.
    command! -nargs=1 FuzzySearchFileInDir FZF <args>
  ]])

  -- Parse a "file:line:col:text" grep line into a quickfix entry. This field
  -- order is the contract the preview ({1}=file, {2}=line) also relies on.
  local function ag_to_qf(line)
    local parts = vim.split(line, ":")
    return {
      filename = parts[1],
      lnum = parts[2],
      col = parts[3],
      text = table.concat(parts, ":", 4),
    }
  end

  -- Handle the fzf result: the pressed --expect key is lines[1], selections
  -- follow. ctrl-q -> quickfix; ctrl-t/x/v -> tab/split/vsplit; otherwise open
  -- the first item and spill any extra selections into the quickfix list.
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
  -- Preview starts hidden (keeps these searches fast); alt-p toggles a bat
  -- preview of {1}=file at {2}=line, scrolled so the match is centered.
  -- Tab-selected items: '+ ' marker (trailing space) + green marker/line text.
  local SEARCH_OPTIONS = "--ansi --expect=ctrl-t,ctrl-v,ctrl-x,ctrl-q --delimiter : --nth 4.. "
    .. "--multi --bind=ctrl-a:select-all,ctrl-d:deselect-all,alt-p:toggle-preview "
    .. "--preview 'bat --style=numbers --color=always --highlight-line {2} -- {1}' "
    .. "--preview-window 'right:50%:+{2}-/2:hidden' "
    .. "--marker='+ ' "
    .. "--color hl:68,hl+:110,marker:#a6da95,selected-fg:#a6da95"

  -- Full-text search via ag (silver searcher); results feed ag_handler.
  -- --follow: makes ag follow symlinks when searching
  vim.api.nvim_create_user_command("CustomFullTextSearch", function(opts)
    local query = opts.args ~= "" and opts.args or "^(?=.)"
    vim.fn["fzf#run"]({
      source = string.format('ag --nogroup --column --color --follow "%s"', query),
      ["sink*"] = ag_handler,
      options = SEARCH_OPTIONS .. search_label_flags_str("Full Text - ag (text only)"),
      down = "50%",
    })
  end, { nargs = "*" })

  -- Base ripgrep invocation for the search below; --max-columns guards long lines.
  local RG_CMD = "rg --column --line-number --no-heading --color=always --smart-case --max-columns=500"

  -- Faster full-text search via ripgrep; same ag_handler + SEARCH_OPTIONS.
  vim.api.nvim_create_user_command("CustomFullTextSearchRg", function(opts)
    local query = opts.args ~= "" and opts.args or "."
    vim.fn["fzf#run"]({
      source = RG_CMD .. " " .. vim.fn.shellescape(query),
      ["sink*"] = ag_handler,
      options = SEARCH_OPTIONS .. search_label_flags_str("Full Text - rg (text only)"),
      down = "50%",
    })
  end, { nargs = "*" })
end

-- Fuzzy file finder rooted at the resolved project root. Mirrors the built-in
-- :FZF (name "FZF" + dir keeps its dir-relative open behavior) but swaps the
-- long dir-path prompt for a labeled border.
function M.find_files()
  vim.fn["fzf#run"](vim.fn["fzf#wrap"]("FZF", {
    dir = root.get(),
    options = with_label({ "--multi", "--scheme", "path" }, "Files"),
  }, 0))
end

-- Fuzzy file finder limited to files beside the current file.
function M.find_sibling_files()
  vim.cmd("FuzzySearchSiblingFilesInCurrentDir")
end

-- Pick among git-modified files.
function M.find_changed_files()
  vim.cmd("SearchChangedFilesFZF")
end

-- Git-modified files filtered to those whose path ends with `extension`.
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
    options = label_flags("Git Status (" .. extension .. ")"),
    window = { height = 0.84, width = 1 },
  })
end

-- Fuzzy file finder scoped to a single directory (fd).
function M.find_resource_in_dir(dir)
  local title = vim.fn.fnamemodify(dir, ":t")
  vim.fn["fzf#run"](vim.fn["fzf#wrap"]({
    source = "fd --type f . " .. vim.fn.fnameescape(dir),
    options = label_flags(title),
    window = { height = 0.84, width = 1 },
  }))
end

-- Fuzzy file finder across several dirs, listed by path relative to each dir.
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
    options = with_label({ "--with-nth=1", "--delimiter=\t", "--layout=default" }, dirs_label(available)),
    sink = function(selected)
      local full_path = selected:match("\t(.+)$")
      if full_path then vim.cmd("edit " .. vim.fn.fnameescape(full_path)) end
    end,
    window = { height = 0.84, width = 1 },
  })
end

-- Fuzzy file finder across several directories, using absolute paths.
function M.find_files_in_dirs(dirs)
  local available = vim.tbl_filter(function(d) return d and d ~= "" and vim.fn.isdirectory(d) == 1 end, dirs)
  if #available == 0 then return end
  vim.fn["fzf#run"]({
    source = "fd --type f . " .. table.concat(available, " "),
    sink = "e",
    options = label_flags(dirs_label(available)),
    window = { height = 0.84, width = 1 },
  })
end

-- MRU picker: open buffers + v:oldfiles, deduped and limited to files in cwd.
function M.oldfiles()
  local cwd = vim.fn.getcwd() .. "/"
  local seen = {}
  local files = {}

  -- Add a path once, only if it lives under cwd and is a readable file.
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
    options = with_label({ "-m", "-x", "+s" }, "MRU"),
    window = { height = 0.84, width = 1 },
  })
end

-- Fuzzy-search lines within the current buffer (:BLines, no preview).
function M.buffer_fuzzy_find()
  vim.fn["fzf#vim#buffer_lines"]("", { options = search_label_flags("Buffer Lines (text only)") }, 0)
end

-- Switch between open buffers (:Buffers, with the fzf.vim preview).
function M.buffer_list()
  vim.fn["fzf#vim#buffers"](
    "",
    vim.fn["fzf#vim#with_preview"]({ placeholder = "{1}", options = label_flags("Buffers") }),
    0
  )
end

-- Live grep across the project (fullscreen :Ag!, with the fzf.vim preview).
function M.live_grep()
  vim.fn["fzf#vim#ag"](
    "",
    vim.fn["fzf#vim#with_preview"]({ options = search_label_flags("Ag (text + filename)") }),
    1
  )
end

-- Live grep scoped to the given dirs, with the fzf.vim bat preview.
function M.live_grep_in_dirs(dirs)
  local available = vim.tbl_filter(function(d) return d and d ~= "" and vim.fn.isdirectory(d) == 1 end, dirs)
  if #available == 0 then return end
  local dirs_str = table.concat(vim.tbl_map(vim.fn.shellescape, available), " ")
  vim.fn["fzf#vim#grep"](
    "rg --column --line-number --no-heading --color=always --smart-case . " .. dirs_str,
    1,
    vim.fn["fzf#vim#with_preview"]({ options = search_label_flags(dirs_label(available) .. " - rg (text + filename)") }),
    0
  )
end

-- Full-text search via ag (no preview by default; alt-p toggles it).
function M.custom_full_text_search()
  vim.cmd("CustomFullTextSearch")
end

-- Full-text search via ripgrep (faster; no preview by default, alt-p toggles).
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
    vim.fn["fzf#vim#with_preview"]({ options = search_label_flags("Live Grep - rg (text + filename)") }),
    0
  )
end

-- Like custom_full_text_search (--follow symlinks) but with a bat-backed preview window
function M.custom_full_text_search_with_preview()
  vim.fn["fzf#vim#grep"](
    "rg --column --line-number --no-heading --color=always --smart-case --follow --colors 'match:none' .",
    1,
    vim.fn["fzf#vim#with_preview"]({ options = search_label_flags("Full Text - rg preview (text + filename)") }),
    0
  )
end

-- rg --column emits "path:line:col:text" and fzf#vim#grep already sets ':' as
-- the delimiter, so field 4 onward is the matched text; limiting --nth to it
-- keeps the query from matching file paths.
local CONTENT_ONLY_NTH_FLAG = "--nth=4.."

-- rg invocation over git-changed and untracked files, or nil when nothing changed.
local function changed_files_grep_command()
  local lines = vim.fn.systemlist("git diff --name-only --diff-filter=ACMR HEAD && git ls-files --others --exclude-standard")
  local files = vim.tbl_filter(function(f) return f ~= "" and vim.fn.filereadable(f) == 1 end, lines)

  if #files == 0 then
    vim.notify("No changed/added files", vim.log.levels.INFO)
    return nil
  end

  local file_args = table.concat(vim.tbl_map(vim.fn.shellescape, files), " ")

  return "rg --column --line-number --no-heading --color=always --smart-case . " .. file_args
end

-- Live grep restricted to git-changed and untracked files, with preview.
function M.live_grep_changed_files()
  local grep_command = changed_files_grep_command()
  if not grep_command then return end

  vim.fn["fzf#vim#grep"](
    grep_command,
    1,
    vim.fn["fzf#vim#with_preview"]({ options = search_label_flags("Changed Files - rg (text + filename)") }),
    0
  )
end

-- Same as live_grep_changed_files, but the query matches only line content and
-- never the file path.
function M.live_grep_changed_files_content_only()
  local grep_command = changed_files_grep_command()
  if not grep_command then return end

  local options = search_label_flags("Changed Files - rg (text only)")
  table.insert(options, CONTENT_ONLY_NTH_FLAG)

  vim.fn["fzf#vim#grep"](
    grep_command,
    1,
    vim.fn["fzf#vim#with_preview"]({ options = options }),
    0
  )
end

-- Fuzzy-search lines across all listed buffers (:FZFLines).
function M.search_lines_in_all_buffers()
  vim.cmd("FZFLines")
end

-- Bare :FZF picker menu (current working directory).
function M.open_picker_menu()
  vim.fn["fzf#run"](vim.fn["fzf#wrap"]("FZF", {
    options = with_label({ "--multi", "--scheme", "path" }, "Files (cwd)"),
  }, 0))
end

return M
