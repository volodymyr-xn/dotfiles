local R = require("my_extensions.fuzzy_picker_selector")

local fzf_vim_picker = require("my_extensions.pickers.fzf_vim")
fzf_vim_picker.setup()

local js_dir = CustomFindFirstAvailableDir({ "app/javascript", "app/assets/javascripts" })
local components_dir = CustomFindFirstAvailableDir({ "app/components", "app/view_components" })

local task_dirs = { vim.env.C_PLANS, vim.env.C_DOCS, vim.env.C_DRAFT_DOCS }

local function CustomSearchInDirs(dirs, opts)
  opts = opts or {}
  local action = opts.show_relative_path and "find_files_in_dirs_relative" or "find_files_in_dirs"
  R.call(action, dirs)
end

local opts = { noremap = true }

vim.keymap.set("n", "<C-p>", function() R.call("find_files") end, vim.tbl_extend("force", opts, { desc = "Find files" }))
vim.keymap.set("n", "<Leader>i", function() R.call("find_sibling_files") end, vim.tbl_extend("force", opts, { desc = "Find sibling files" }))

vim.keymap.set("n", "q", function() R.call("find_changed_files") end, vim.tbl_extend("force", opts, { desc = "Find changed files" }))
vim.keymap.set("n", "<leader>q1", function() R.call("find_changed_files_by_extension", "%.js") end, vim.tbl_extend("force", opts, { desc = "Find changed JS files" }))
vim.keymap.set("n", "<leader>qj", function() R.call("find_changed_files_by_extension", "%.js") end, vim.tbl_extend("force", opts, { desc = "Find changed JS files" }))
vim.keymap.set("n", "<leader>q2", function() R.call("find_changed_files_by_extension", "%.rb") end, vim.tbl_extend("force", opts, { desc = "Find changed RB files" }))
vim.keymap.set("n", "<leader>q3", function() R.call("find_changed_files_by_extension", "%.html%.erb") end, vim.tbl_extend("force", opts, { desc = "Find changed ERB files" }))
vim.keymap.set("n", "<leader>q4", function() R.call("find_changed_files_by_extension", "%.s?css") end, vim.tbl_extend("force", opts, { desc = "Find changed CSS files" }))

vim.keymap.set("n", "<Leader>f", function() R.call("find_resource_in_dir", components_dir) end, vim.tbl_extend("force", opts, { desc = "Find view components" }))
vim.keymap.set("n", "<Leader>m", function() R.call("find_resource_in_dir", "app/models") end, vim.tbl_extend("force", opts, { desc = "Find models" }))
vim.keymap.set("n", "<Leader>c", function() R.call("find_resource_in_dir", "app/controllers") end, vim.tbl_extend("force", opts, { desc = "Find controllers" }))
vim.keymap.set("n", "<Leader>j", function() CustomSearchInDirs({ "app/javascript", "app/assets/javascripts" }, { show_relative_path = true }) end, vim.tbl_extend("force", opts, { desc = "Find JS files" }))
vim.keymap.set("n", "<Leader>s", function() R.call("find_resource_in_dir", "app/assets/stylesheets") end, vim.tbl_extend("force", opts, { desc = "Find CSS files" }))
vim.keymap.set("n", "<Leader>d", function() R.call("find_resource_in_dir", "app/views") end, vim.tbl_extend("force", opts, { desc = "Find views" }))
vim.keymap.set("n", "<Leader>b", function() R.call("find_resource_in_dir", "config/locales") end, vim.tbl_extend("force", opts, { desc = "Find i18n files" }))

vim.keymap.set("n", "<Leader>qq", function() R.call("find_files_in_dirs", task_dirs) end, vim.tbl_extend("force", opts, { desc = "Find files in task dirs" }))

vim.keymap.set("n", "<Leader>x", function() R.call("buffer_fuzzy_find") end, vim.tbl_extend("force", opts, { desc = "Fuzzy find in buffer" }))
vim.keymap.set("n", ",q", function() R.call("open_picker_menu") end, vim.tbl_extend("force", opts, { desc = "Open picker menu" }))

vim.keymap.set("n", "<Leader>o", function() fzf_vim_picker.live_grep() end, vim.tbl_extend("force", opts, { desc = "Live grep (fzf.vim)" }))
vim.keymap.set("n", "<Leader>p", function() fzf_vim_picker.custom_full_text_search() end, vim.tbl_extend("force", opts, { desc = "Custom full text search (fzf.vim)" }))

vim.keymap.set("n", "st", function() R.cycle() end, { desc = "Switch picker" })

vim.cmd("command! PickerSwitch lua require('my_extensions.fuzzy_picker_selector').cycle()")
vim.cmd("command! -nargs=1 PickerSet lua require('my_extensions.fuzzy_picker_selector').set(<q-args>)")
