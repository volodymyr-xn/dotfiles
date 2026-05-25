local M = {}

local state = {
  searching_filepaths = false,
  using_loclist = false,
}

local config = {
  ackprg = nil,
  default_options = " -s -H --nopager --nocolor --nogroup --column",
  use_dispatch = false,
  apply_qmappings = true,
  apply_lmappings = true,
  qhandler = "botright copen",
  lhandler = "botright lopen",
  highlight = false,
  autoclose = false,
  autofold_results = false,
  use_cword_for_empty_search = true,
  mappings = {
    t = "<C-W><CR><C-W>T",
    T = "<C-W><CR><C-W>TgT<C-W>j",
    o = "<CR><C-W>p",
    p = "<CR><C-W>p",
    O = "<CR><C-W>p<C-W>c",
    go = "<CR><C-W>p",
    h = "<C-W><CR><C-W>K",
    H = "<C-W><CR><C-W>K<C-W>b",
    v = "<C-W><CR><C-W>H<C-W>b<C-W>J<C-W>t",
    gv = "<C-W><CR><C-W>H<C-W>b<C-W>J"
  }
}

local function warn(msg)
  vim.api.nvim_echo({{"Ack: " .. msg, "WarningMsg"}}, true, {})
end

local function init(cmd)
  state.searching_filepaths = cmd:match('-g$') ~= nil
  state.using_loclist = cmd:match('^l') ~= nil

  if config.use_dispatch and state.using_loclist then
    warn('Dispatch does not support location lists! Proceeding with quickfix...')
    state.using_loclist = false
  end
end

local function using_loclist()
  return state.using_loclist
end

local function searching_filepaths()
  return state.searching_filepaths
end

local function using_list_mappings()
  if using_loclist() then
    return config.apply_lmappings
  else
    return config.apply_qmappings
  end
end

local function get_doc_locations()
  local dp = ''
  for _, p in ipairs(vim.api.nvim_list_runtime_paths()) do
    local doc_path = p .. '/doc/'
    if vim.fn.isdirectory(doc_path) == 1 then
      dp = doc_path .. '*.txt ' .. dp
    end
  end
  return dp
end

local function highlight_pattern(args)
  if not config.highlight then
    return
  end

  local pattern = vim.fn.matchstr(args, [=[\v(-)@<!(\<)@<=\w+|['"]zs.{-}ze['"]]=])
  if pattern ~= '' then
    vim.fn.setreg('/', pattern)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(":let &hlsearch=1 | echo <CR>", true, false, true), "n", false)
  end
end

local function apply_mappings()
  if not using_list_mappings() or vim.bo.filetype ~= 'qf' then
    return
  end

  local wintype = using_loclist() and 'l' or 'c'
  local closemap = ':' .. wintype .. 'close<CR>'
  config.mappings.q = closemap

  local opts = {buffer = true, silent = true, noremap = true}

  if config.autoclose then
    for key, mapping in pairs(config.mappings) do
      vim.keymap.set('n', key, mapping .. closemap, opts)
    end
    vim.keymap.set('n', '<CR>', '<CR>' .. closemap, opts)
  else
    for key, mapping in pairs(config.mappings) do
      vim.keymap.set('n', key, mapping, opts)
    end
  end

  if vim.g.ackpreview then
    vim.keymap.set('n', 'j', 'j<CR><C-W><C-P>', opts)
    vim.keymap.set('n', 'k', 'k<CR><C-W><C-P>', opts)
    vim.keymap.set('n', '<Down>', 'j', opts)
    vim.keymap.set('n', '<Up>', 'k', opts)
  end
end

local function search_with_grep(grepcmd, grepprg, grepargs, grepformat)
  local grepprg_bak = vim.o.grepprg
  local grepformat_bak = vim.o.grepformat

  vim.o.grepprg = grepprg
  vim.o.grepformat = grepformat

  local ok, err = pcall(function()
    vim.cmd('silent ' .. grepcmd .. ' ' .. grepargs)
  end)

  vim.o.grepprg = grepprg_bak
  vim.o.grepformat = grepformat_bak

  if not ok and err then
    warn('Search failed: ' .. tostring(err))
  end
end

local function search_with_dispatch(grepprg, grepargs, grepformat)
  local makeprg_bak = vim.bo.makeprg
  local errorformat_bak = vim.bo.errorformat

  local final_grepprg = grepprg
  if searching_filepaths() then
    final_grepprg = grepprg .. ' -g'
  end

  vim.bo.makeprg = final_grepprg .. ' ' .. grepargs
  vim.bo.errorformat = grepformat

  local ok, err = pcall(vim.cmd, 'Make')

  vim.bo.makeprg = makeprg_bak
  vim.bo.errorformat = errorformat_bak

  if not ok and err then
    warn('Dispatch search failed: ' .. tostring(err))
  end
end

function M.show_results()
  local handler = using_loclist() and config.lhandler or config.qhandler
  vim.cmd(handler)
  apply_mappings()
  vim.cmd('redraw!')
end

function M.ack(cmd, args)
  init(cmd)
  vim.cmd('redraw')

  local grepprg = config.ackprg
  local grepformat = '%f:%l:%c:%m,%f:%l:%m'

  if searching_filepaths() then
    grepprg = grepprg:gsub('-H', ''):gsub('--column', '')
    grepformat = '%f'
  end

  if args == '' then
    if not config.use_cword_for_empty_search then
      print("No regular expression found.")
      return
    end
  end

  local grepargs = args
  if args == '' then
    grepargs = vim.fn.expand("<cword>")
  end

  if grepargs == "" then
    print("No regular expression found.")
    return
  end

  local escaped_args = vim.fn.escape(grepargs, '|#%')

  print("Searching ...")

  if config.use_dispatch then
    search_with_dispatch(grepprg, escaped_args, grepformat)
  else
    search_with_grep(cmd, grepprg, escaped_args, grepformat)
  end

  M.show_results()
  highlight_pattern(grepargs)
end

function M.ack_from_search(cmd, args)
  local search = vim.fn.getreg('/')
  search = search:gsub('\\<', '\\b'):gsub('\\>', '\\b')
  M.ack(cmd, '"' .. search .. '" ' .. args)
end

function M.ack_help(cmd, args)
  local doc_args = args .. ' ' .. get_doc_locations()
  M.ack(cmd, doc_args)
end

function M.ack_window(cmd, args)
  local files = vim.fn.tabpagebuflist()

  local unique_files = {}
  local seen = {}
  for _, bufnr in ipairs(files) do
    if not seen[bufnr] then
      seen[bufnr] = true
      table.insert(unique_files, bufnr)
    end
  end

  local filenames = {}
  for _, bufnr in ipairs(unique_files) do
    local name = vim.fn.bufname(bufnr)
    if name ~= '' then
      local fullpath = vim.fn.fnamemodify(name, ':p')
      table.insert(filenames, vim.fn.shellescape(fullpath))
    end
  end

  local file_args = args .. ' ' .. table.concat(filenames, ' ')
  M.ack(cmd, file_args)
end

function M.setup(opts)
  opts = opts or {}

  if opts.ackprg then
    config.ackprg = opts.ackprg
  else
    if vim.fn.executable('ag') == 1 then
      config.ackprg = 'ag --vimgrep'
    elseif vim.fn.executable('ack-grep') == 1 then
      config.ackprg = 'ack-grep' .. config.default_options
    elseif vim.fn.executable('ack') == 1 then
      config.ackprg = 'ack' .. config.default_options
    else
      warn('No ack executable found')
      return
    end
  end

  if opts.use_dispatch ~= nil then
    config.use_dispatch = opts.use_dispatch
    if config.use_dispatch and vim.fn.exists(':Dispatch') == 0 then
      warn('Dispatch not loaded! Falling back to use_dispatch = false')
      config.use_dispatch = false
    end
  end

  if opts.qhandler then config.qhandler = opts.qhandler end
  if opts.lhandler then config.lhandler = opts.lhandler end
  if opts.highlight ~= nil then config.highlight = opts.highlight end
  if opts.autoclose ~= nil then config.autoclose = opts.autoclose end
  if opts.autofold_results ~= nil then config.autofold_results = opts.autofold_results end
  if opts.use_cword_for_empty_search ~= nil then config.use_cword_for_empty_search = opts.use_cword_for_empty_search end

  if opts.mappings then
    config.mappings = vim.tbl_extend('force', config.mappings, opts.mappings)
  end

  vim.api.nvim_create_user_command('Ack', function(cmd_opts)
    M.ack('grep' .. (cmd_opts.bang and '!' or ''), cmd_opts.args)
  end, {nargs = '*', bang = true, complete = 'file'})

  vim.api.nvim_create_user_command('AckAdd', function(cmd_opts)
    M.ack('grepadd' .. (cmd_opts.bang and '!' or ''), cmd_opts.args)
  end, {nargs = '*', bang = true, complete = 'file'})

  vim.api.nvim_create_user_command('AckFromSearch', function(cmd_opts)
    M.ack_from_search('grep' .. (cmd_opts.bang and '!' or ''), cmd_opts.args)
  end, {nargs = '*', bang = true, complete = 'file'})

  vim.api.nvim_create_user_command('LAck', function(cmd_opts)
    M.ack('lgrep' .. (cmd_opts.bang and '!' or ''), cmd_opts.args)
  end, {nargs = '*', bang = true, complete = 'file'})

  vim.api.nvim_create_user_command('LAckAdd', function(cmd_opts)
    M.ack('lgrepadd' .. (cmd_opts.bang and '!' or ''), cmd_opts.args)
  end, {nargs = '*', bang = true, complete = 'file'})

  vim.api.nvim_create_user_command('AckFile', function(cmd_opts)
    M.ack('grep' .. (cmd_opts.bang and '!' or '') .. ' -g', cmd_opts.args)
  end, {nargs = '*', bang = true, complete = 'file'})

  vim.api.nvim_create_user_command('AckHelp', function(cmd_opts)
    M.ack_help('grep' .. (cmd_opts.bang and '!' or ''), cmd_opts.args)
  end, {nargs = '*', bang = true, complete = 'help'})

  vim.api.nvim_create_user_command('LAckHelp', function(cmd_opts)
    M.ack_help('lgrep' .. (cmd_opts.bang and '!' or ''), cmd_opts.args)
  end, {nargs = '*', bang = true, complete = 'help'})

  vim.api.nvim_create_user_command('AckWindow', function(cmd_opts)
    M.ack_window('grep' .. (cmd_opts.bang and '!' or ''), cmd_opts.args)
  end, {nargs = '*', bang = true})

  vim.api.nvim_create_user_command('LAckWindow', function(cmd_opts)
    M.ack_window('lgrep' .. (cmd_opts.bang and '!' or ''), cmd_opts.args)
  end, {nargs = '*', bang = true})
end

return M
