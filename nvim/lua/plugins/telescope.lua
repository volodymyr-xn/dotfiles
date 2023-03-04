require('telescope').setup{
  defaults = {
      vimgrep_arguments = {
      "rg",
      "-L",
      "--color=never",
      "--no-heading",
      "--with-filename",
      "--line-number",
      "--column",
      "--smart-case",
    },
    -- prompt_prefix = "   ",
    prompt_prefix = " 🔍  ",
    selection_caret = "  ",
    entry_prefix = "  ",
    initial_mode = "insert",
    selection_strategy = "reset",
    -- sorting_strategy = "ascending",
    layout_strategy = "horizontal",
    layout_config = {
      horizontal = {
        preview_width = 0.55,
        results_width = 0.8,
      },
      vertical = {
        mirror = false,
      },
      width = 0.99,
      height = 0.99,
      preview_cutoff = 120,
    },
    file_sorter = require("telescope.sorters").get_fuzzy_file,
    file_ignore_patterns = { "node_modules" },
    generic_sorter = require("telescope.sorters").get_generic_fuzzy_sorter,
    path_display = { "truncate" },
    winblend = 0,
    border = {},
    borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
    color_devicons = true,
    set_env = { ["COLORTERM"] = "truecolor" }, -- default = nil,
    file_previewer = require("telescope.previewers").vim_buffer_cat.new,
    grep_previewer = require("telescope.previewers").vim_buffer_vimgrep.new,
    qflist_previewer = require("telescope.previewers").vim_buffer_qflist.new,
    -- Developer configurations: Not meant for general override
    buffer_previewer_maker = require("telescope.previewers").buffer_previewer_maker,
    mappings = {
      n = { ["q"] = require("telescope.actions").close },
      i = { ["<esc>"] = require("telescope.actions").close },
    },
  },
  extensions_list = { "themes", "terms" },
  pickers = {
    -- Default configuration for builtin pickers goes here:
    -- picker_name = {
    --   picker_config_key = value,
    --   ...
    -- }
    -- Now the picker_config_key will be applied every time you call this
    -- builtin picker
  },
  extensions = {
    -- Your extension configuration goes here:
    -- extension_name = {
    --   extension_config_key = value,
    -- }
    -- please take a look at the readme of the extension you want to configure
  }
}

-- ========================= Telescope VIM mappings ==============================
local telescope = require('telescope.builtin')

-- Regular files search without preview
local function find_files_wihout_preview()
  telescope.find_files({ previewer = false })
end

-- Full text search without preview
local function full_text_search_wihout_preview()
  telescope.live_grep({ previewer = false })
end

function find_reource_in_dir(dir)
  return function() telescope.find_files({ cwd = dir, previewer = false }) end
end

function find_sibling_files()
  -- telescope.find_files( { cwd = vim.fn.expand('%:p:h') })
  telescope.find_files( {
    cwd = vim.fn.expand('%:h'),
    -- We need to directly call CLI searcher "rg" to set "max depth for searching in dirs"
    find_command = { 'rg', '--files', '--no-ignore', '--hidden', '-g', '!.git', '--max-depth', '1' }
  })
end

local find_models = find_reource_in_dir("app/models")
local find_controllers = find_reource_in_dir("app/controllers")
local find_css = find_reource_in_dir("app/assets/stylesheets")
local find_js = find_reource_in_dir("app/assets/javascripts")
local find_components = find_reource_in_dir("app/components")
local find_views = find_reource_in_dir("app/views")
local find_i18n = find_reource_in_dir("config/locales/custom_updates")
-- " Search sibling files in same directory as current file(with preview window)
-- noremap <Leader>i :FuzzySearchSiblingFilesInCurrentDir <CR>

-- Search files
-- vim.keymap.set('n', '<C-p>', telescope.find_files, { noremap = true })
vim.keymap.set('n', '<C-p>', find_files_wihout_preview, { noremap = true })

vim.keymap.set('n', '<Leader>i', find_sibling_files, { noremap = true })

-- Full text search
vim.keymap.set('n', '<Leader>o', telescope.live_grep, {})
vim.keymap.set('n', '<Leader>p', full_text_search_wihout_preview, {})

-- Find in varios Rails projekt dirs
vim.keymap.set('n', '<Leader>m', find_models, {})
vim.keymap.set('n', '<Leader>c', find_controllers, {})
vim.keymap.set('n', '<Leader>j', find_js, {})
vim.keymap.set('n', '<Leader>s', find_css, {})
vim.keymap.set('n', '<Leader>f', find_components, {})
vim.keymap.set('n', '<Leader>d', find_views, {})
vim.keymap.set('n', '<Leader>g', find_i18n, {})


-- Define a new highlight group for the border color
vim.cmd('highlight TelescopeBorder guifg=#efb993')
vim.cmd('highlight link TelescopeBorder FloatBorder')
vim.cmd('highlight link Directory Conditional')
