local R = require("my_plugins.fuzzy_picker_selector")
local CustomFileSelectors = require("custom_file_selectors.fzf_vim")

CustomFileSelectors.setup()

local js_dirs = { "app/javascript", "app/assets/javascripts" }
local components_dir = CustomFindFirstAvailableDir({ "app/components", "app/view_components" })

local task_dirs = { vim.env.C_PLANS, vim.env.C_DOCS, vim.env.C_DRAFT_DOCS }

-- Search files in multiple dirs, optionally showing relative paths
local function search_in_dirs(dirs, show_relative)
  local action = show_relative and "find_files_in_dirs_relative" or "find_files_in_dirs"
  R.call(action, dirs)
end

-- Normal-mode keymap with noremap and a description
local function nmap(key, fn, desc)
  vim.keymap.set("n", key, fn, { noremap = true, desc = desc })
end

nmap("<C-p>",
  function() R.call("find_files") end,
  "Find files"
)

nmap("<Leader>i",
  function() R.call("find_sibling_files") end,
  "Find sibling files"
)

nmap("q",
  function() R.call("find_changed_files") end,
  "Find changed files"
)

nmap("<Leader>f",
  function() R.call("find_resource_in_dir", components_dir) end,
  "Find view components"
)

nmap("<Leader>m",
  function() R.call("find_resource_in_dir", "app/models") end,
  "Find models"
)

nmap("<Leader>c",
  function() R.call("find_resource_in_dir", "app/controllers") end,
  "Find controllers"
)

nmap("<Leader>j",
  function() search_in_dirs(js_dirs, true) end,
  "Find JS files"
)

nmap("<Leader>s",
  function() R.call("find_resource_in_dir", "app/assets/stylesheets") end,
  "Find CSS files"
)

nmap("<Leader>d",
  function() R.call("find_resource_in_dir", "app/views") end,
  "Find views"
)

nmap("<Leader>b",
  function() R.call("find_resource_in_dir", "config/locales") end,
  "Find i18n files"
)


nmap("s[",
  function() R.call("buffer_fuzzy_find") end,
  "Fuzzy find in buffer"
)

nmap(",q",
  function() R.call("open_picker_menu") end,
  "Open picker menu"
)

nmap("<Leader>o",
  function() CustomFileSelectors.live_grep() end,
  "Live grep (Ag)"
)

-- Much better performance that Live grep with (Ag)
nmap("<Leader>p",
  function() CustomFileSelectors.custom_full_text_search_rg() end,
  "Custom full text search rg+reload (fzf.vim)"
)

nmap("si",
  function() CustomFileSelectors.custom_full_text_search() end,
  "Custom full text search (fzf.vim)"
)

-- bat-preview variant of <Leader>o (live grep / Ag)
nmap("sg",
  function() CustomFileSelectors.live_grep_with_preview() end,
  "Live grep with bat preview (Ag)"
)

-- bat-preview variant of sp (full text search)
nmap("s]",
  function() CustomFileSelectors.custom_full_text_search_with_preview() end,
  "Full text search with bat preview (fzf.vim)"
)

nmap("so",
  function() CustomFileSelectors.search_lines_in_all_buffers() end,
  "Search lines in all buffers"
)

nmap("sp",
  function() CustomFileSelectors.live_grep_changed_files() end,
  "Full text search in changed files"
)

-- Variant of sp that ignores file names, matching only line content
nmap("sn",
  function() CustomFileSelectors.live_grep_changed_files_content_only() end,
  "Full text search in changed files (text only)"
)

-- MRU picker: open buffers + v:oldfiles, deduped and limited to cwd
nmap("sl",
  function() R.call("oldfiles") end,
  "Recently opened files (MRU, cwd only)"
)

nmap("sj",
  function() R.call("buffer_list") end,
  "Select buffer"
)

-- Switch between configured pickers (telescope / fzf-lua)
nmap("st",
  function() R.cycle() end,
  "Switch picker"
)

-- Telescope buffer picker
-- vim.api.nvim_set_keymap('n', '<Leader>h', ':Telescope jumplist<CR>', {noremap = true, silent = false })
-- vim.api.nvim_set_keymap('n', '<Leader>q', ':Telescope buffers<CR>', {noremap = true, silent = false })
nmap("<Leader>h",
  function() vim.cmd("Telescope buffers") end,
  "Telescope buffers"
)

-- vim.keymap.set('n', 'sj', ':FzfLua<cr>', { noremap = true, silent = true, desc = "FzfLua select" })

vim.cmd("command! PickerSwitch lua require('my_plugins.fuzzy_picker_selector').cycle()")
vim.cmd("command! -nargs=1 PickerSet lua require('my_plugins.fuzzy_picker_selector').set(<q-args>)")
