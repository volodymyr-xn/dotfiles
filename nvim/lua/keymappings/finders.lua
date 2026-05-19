local R = require("my_plugins.fuzzy_picker_selector")
local CustomFileSelectors = require("custom_file_selectors.fzf_vim")

CustomFileSelectors.setup()

local js_dirs = { "app/javascript", "app/assets/javascripts" }
local components_dir = CustomFindFirstAvailableDir({ "app/components", "app/view_components" })

local task_dirs = { vim.env.C_PLANS, vim.env.C_DOCS, vim.env.C_DRAFT_DOCS }
local notes_dirs = { vim.env.C_DOCS, vim.env.C_PLANS, vim.env.C_RESEARCH, vim.env.C_TEMP }

-- Search files in multiple dirs, optionally showing relative paths
local function search_in_dirs(dirs, show_relative)
  local action = show_relative and "find_files_in_dirs_relative" or "find_files_in_dirs"
  R.call(action, dirs)
end

local function map(key, fn, desc)
  vim.keymap.set("n", key, fn, { noremap = true, desc = desc })
end

map("<C-p>",
  function() R.call("find_files") end,
  "Find files")

map("<Leader>i",
  function() R.call("find_sibling_files") end,
  "Find sibling files")

map("q",
  function() R.call("find_changed_files") end,
  "Find changed files")

map("<leader>q1",
  function() R.call("find_changed_files_by_extension", "%.js") end,
  "Find changed JS files")

map("<leader>qj",
  function() R.call("find_changed_files_by_extension", "%.js") end,
  "Find changed JS files")

map("<leader>q2",
  function() R.call("find_changed_files_by_extension", "%.rb") end,
  "Find changed RB files")

map("<leader>q3",
  function() R.call("find_changed_files_by_extension", "%.html%.erb") end,
  "Find changed ERB files")

map("<leader>q4",
  function() R.call("find_changed_files_by_extension", "%.s?css") end,
  "Find changed CSS files")

map("<Leader>f",
  function() R.call("find_resource_in_dir", components_dir) end,
  "Find view components")

map("<Leader>m",
  function() R.call("find_resource_in_dir", "app/models") end,
  "Find models")

map("<Leader>c",
  function() R.call("find_resource_in_dir", "app/controllers") end,
  "Find controllers")

map("<Leader>j",
  function() search_in_dirs(js_dirs, true) end,
  "Find JS files")

map("<Leader>s",
  function() R.call("find_resource_in_dir", "app/assets/stylesheets") end,
  "Find CSS files")

map("<Leader>d",
  function() R.call("find_resource_in_dir", "app/views") end,
  "Find views")

map("<Leader>b",
  function() R.call("find_resource_in_dir", "config/locales") end,
  "Find i18n files")


map("<Leader>qq",
  function() R.call("find_files_in_dirs", task_dirs) end,
  "Find files in task dirs")

map("si",
  function() R.call("buffer_fuzzy_find") end,
  "Fuzzy find in buffer")

map(",q",
  function() R.call("open_picker_menu") end,
  "Open picker menu")

map("<Leader>o",
  function() CustomFileSelectors.live_grep() end,
  "Live grep (Ag)")

map("<Leader>p",
  function() CustomFileSelectors.custom_full_text_search() end,
  "Custom full text search (fzf.vim)")

map("s[",
  function() CustomFileSelectors.custom_full_text_search_rg() end,
  "Custom full text search rg+reload (fzf.vim)")

map("so",
  function() CustomFileSelectors.search_lines_in_all_buffers() end,
  "Search lines in all buffers")

map("sp",
  function() CustomFileSelectors.live_grep_changed_files() end,
  "Full text search in changed files")

map("sk",
  function() R.call("live_grep_in_dirs", notes_dirs) end,
  "Search in notes dirs")

map("sl",
  function() R.call("oldfiles") end,
  "Recent files in cwd")

map("sj",
  function() R.call("buffer_list") end,
  "Select buffer")

-- Switch between configured pickers (telescope / fzf-lua)
map("st",
  function() R.cycle() end,
  "Switch picker")

-- Telescope buffer picker
-- vim.api.nvim_set_keymap('n', '<Leader>h', ':Telescope jumplist<CR>', {noremap = true, silent = false })
-- vim.api.nvim_set_keymap('n', '<Leader>q', ':Telescope buffers<CR>', {noremap = true, silent = false })
map("<Leader>h",
  function() vim.cmd("Telescope buffers") end,
  "Telescope buffers")

-- vim.keymap.set('n', 'sj', ':FzfLua<cr>', { noremap = true, silent = true, desc = "FzfLua select" })

vim.cmd("command! PickerSwitch lua require('my_plugins.fuzzy_picker_selector').cycle()")
vim.cmd("command! -nargs=1 PickerSet lua require('my_plugins.fuzzy_picker_selector').set(<q-args>)")
