local util = require("ack.util")

local M = {}

M.defaults = {
  -- Shell command that performs the search: the program plus its flags, with
  -- no pattern. The escaped pattern and any file arguments are appended to
  -- it, and it becomes 'grepprg' for the duration of the search, so `$*` is
  -- honoured and a literal `|` must be written `\\|`. Its output has to match
  -- `file:line:column:text` or `file:line:text`; disable colour and any
  -- grouped/heading output. Left nil so setup() can autodetect one.
  search_command = nil,
  -- Flags appended to a bare `ack`/`ack-grep` binary when autodetecting.
  default_options = " -s -H --nopager --nocolor --nogroup --column",
  -- Run the search asynchronously through vim-dispatch's :Make.
  use_dispatch = false,
  -- Apply the buffer-local result mappings in the quickfix window.
  apply_qmappings = true,
  -- Apply the buffer-local result mappings in the location list window.
  apply_lmappings = true,
  -- Command used to open the quickfix / location list once results land.
  qhandler = "botright copen",
  lhandler = "botright lopen",
  -- Set the search register from the pattern so matches are highlighted.
  highlight = false,
  -- Close the result window after jumping to an entry.
  autoclose = false,
  autofold_results = false,
  -- Search the word under the cursor when no pattern is given.
  use_cword_for_empty_search = true,
  -- Collapse per-match duplicates into one entry per file+line. Needed only
  -- for per-match output (`--vimgrep`, ag or rg). Left nil so setup()
  -- autodetects it from search_command; set it explicitly to override.
  remove_duplicates = nil,
  -- Buffer-local mappings applied in the result window.
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
    gv = "<C-W><CR><C-W>H<C-W>b<C-W>J",
  },
}

M.options = vim.deepcopy(M.defaults)

-- Whether setup() has already resolved a usable configuration.
M.initialized = false

-- First supported search program on PATH. `--vimgrep` output is what the
-- default grepformat expects, and it turns remove_duplicates on below.
local function detect_search_command(default_options)
  if vim.fn.executable("rg") == 1 then
    return "rg --vimgrep"
  elseif vim.fn.executable("ag") == 1 then
    return "ag --vimgrep"
  elseif vim.fn.executable("ack-grep") == 1 then
    return "ack-grep" .. default_options
  elseif vim.fn.executable("ack") == 1 then
    return "ack" .. default_options
  end
end

-- Merge user options over the defaults and resolve the autodetected ones.
-- Returns false (after warning) when no search program is available.
function M.setup(opts)
  local options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})

  options.search_command = options.search_command or detect_search_command(options.default_options)
  if not options.search_command then
    util.warn("No ack executable found")
    return false
  end

  if options.use_dispatch and vim.fn.exists(":Dispatch") == 0 then
    util.warn("Dispatch not loaded! Falling back to use_dispatch = false")
    options.use_dispatch = false
  end

  -- Per-match programs (`--vimgrep`) emit one entry per match instead of one
  -- per line, so dedupe them unless the user decided otherwise.
  if options.remove_duplicates == nil then
    options.remove_duplicates = options.search_command:match("%-%-vimgrep") ~= nil
  end

  M.options = options
  M.initialized = true

  return true
end

return M
