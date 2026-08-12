local config = require("ack.config")
local quickfix = require("ack.quickfix")
local search = require("ack.search")
local util = require("ack.util")

local M = {}

-- Derive the per-search state from the Vim command being run: a leading `l`
-- means the results go to the location list, a bang means stay put instead
-- of opening the first result, a trailing `-g` means we are listing matching
-- filenames instead of matching lines. The `-g` marker is stripped from the
-- command itself; how to express it is up to the search program (see
-- filepath_prg).
local function state_from_cmd(cmd)
  local grepcmd, filepaths = cmd:gsub("%s*%-g%s*$", "")

  local state = {
    grepcmd = grepcmd,
    searching_filepaths = filepaths > 0,
    using_loclist = cmd:match("^l") ~= nil,
    jumping_to_first = cmd:find("!", 1, true) == nil,
  }

  if config.options.use_dispatch and state.using_loclist then
    util.warn("Dispatch does not support location lists! Proceeding with quickfix...")
    state.using_loclist = false
  end

  return state
end

-- Search program invocation that lists matching file names rather than
-- matching lines. ack and ag do that with `-g PATTERN`; ripgrep's `-g` is a
-- glob filter instead, so its file list is piped through a second rg. The
-- pipe must be escaped: Vim parses 'grepprg' as a command line, where a bare
-- `|` would end the :grep command.
local function filepath_prg(search_command)
  if search_command:match("^%s*rg%f[%A]") then
    return "rg --files \\| rg"
  end

  return search_command:gsub("%-H", ""):gsub("%-%-column", "") .. " -g"
end

-- Every help file on the runtimepath, shell-escaped, for :AckHelp. The glob
-- is expanded here instead of being handed to the shell: a doc/ directory
-- with no .txt files makes zsh abort the whole command line, and plugin
-- paths may contain spaces.
local function get_doc_locations()
  local files = {}

  for _, path in ipairs(vim.api.nvim_list_runtime_paths()) do
    for _, file in ipairs(vim.fn.glob(path .. "/doc/*.txt", false, true)) do
      table.insert(files, vim.fn.shellescape(file))
    end
  end

  return table.concat(files, " ")
end

-- Open the result window and apply its mappings.
function M.show_results(using_loclist)
  quickfix.show_results(using_loclist)
end

-- Core search entry point. `cmd` is the Vim grep command to run (`grep`,
-- `lgrepadd!`, `grep -g`, ...), `args` the raw command-line arguments.
function M.ack(cmd, args)
  local state = state_from_cmd(cmd)
  local options = config.options
  vim.cmd("redraw")

  local grepprg = options.search_command
  local grepformat = "%f:%l:%c:%m,%f:%l:%m"

  if state.searching_filepaths then
    grepprg = filepath_prg(grepprg)
    grepformat = "%f"
  end

  if args == "" and not options.use_cword_for_empty_search then
    print("No regular expression found.")
    return
  end

  local grepargs = args
  if args == "" then
    grepargs = vim.fn.expand("<cword>")
  end

  if grepargs == "" then
    print("No regular expression found.")
    return
  end

  local escaped_args = vim.fn.escape(grepargs, "|#%")

  print("Searching ...")

  if options.use_dispatch then
    search.with_dispatch(grepprg, escaped_args, grepformat)
  else
    local search_succeeded = search.with_grep(state.grepcmd, grepprg, escaped_args, grepformat)

    if options.remove_duplicates then
      search.dedupe(state.using_loclist)
    end

    if search_succeeded then
      if search.result_count(state.using_loclist) == 0 then
        util.warn("No matches found")
      elseif state.jumping_to_first then
        search.jump_to_first(state.using_loclist)
      end
    end
  end

  M.show_results(state.using_loclist)
  quickfix.highlight_pattern(grepargs)
end

-- Search for the contents of the last search register, translating Vim's
-- word boundaries into the regex flavour the search program understands.
function M.ack_from_search(cmd, args)
  local pattern = vim.fn.getreg("/"):gsub("\\<", "\\b"):gsub("\\>", "\\b")
  M.ack(cmd, '"' .. pattern .. '" ' .. args)
end

-- Search the help files of every plugin on the runtimepath.
function M.ack_help(cmd, args)
  M.ack(cmd, args .. " " .. get_doc_locations())
end

-- Search only the files open in the current tab's windows.
function M.ack_window(cmd, args)
  local seen = {}
  local filenames = {}

  for _, bufnr in ipairs(vim.fn.tabpagebuflist()) do
    local name = not seen[bufnr] and vim.fn.bufname(bufnr) or ""
    seen[bufnr] = true

    if name ~= "" then
      table.insert(filenames, vim.fn.shellescape(vim.fn.fnamemodify(name, ":p")))
    end
  end

  M.ack(cmd, args .. " " .. table.concat(filenames, " "))
end

-- Route a registered user command to its handler, initializing the plugin
-- with defaults if the user never called setup().
function M.dispatch(spec, cmd_opts)
  if not config.initialized and not M.setup() then
    return
  end

  local cmd = spec.grepcmd .. (cmd_opts.bang and "!" or "") .. (spec.suffix or "")
  M[spec.handler](cmd, cmd_opts.args or "")
end

-- Optional: only needed to override the defaults. Commands are registered
-- by plugin/ack.lua whether or not this runs.
function M.setup(opts)
  return config.setup(opts)
end

return M
