require('telescope').setup{
  defaults = {
    vimgrep_arguments = {
      -- "rg",
      -- "-L",
      -- "--color=never",
      -- "--no-heading",
      -- "--with-filename",
      -- "--line-number",
      -- "--column",
      -- "--smart-case",
      "ag",
      "--nocolor",
      "--noheading",
      "--numbers",
      "--column",
      "--smart-case",
      "--silent",
      "--vimgrep"
    },
    prompt_prefix = "   ",
    prompt_prefix = " 🔍  ",
    selection_caret = "  ",
    entry_prefix = "  ",
    initial_mode = "insert",
    -- selection_strategy = "reset",
    -- sorting_strategy = "ascending",
    layout_strategy = "horizontal",
    layout_config = {
      horizontal = {
        preview_width = 0.45,
        results_width = 0.80,
      },
      vertical = {
        mirror = false,
      },
      width = 0.99,
      height = 0.99,
      preview_cutoff = 50,
    },
    file_sorter = require("telescope.sorters").get_fzy_sorter,
    generic_sorter = require("telescope.sorters").get_fzy_sorter,
    -- file_previewer = require("telescope.previewers").vim_buffer_cat.new,
    -- grep_previewer = require("telescope.previewers").vim_buffer_vimgrep.new,
    -- qflist_previewer = require("telescope.previewers").vim_buffer_qflist.new,
    file_ignore_patterns = { "node_modules" },
    -- path_display = { "truncate" },
    winblend = 0,
    border = {},
    borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
    color_devicons = true,
    set_env = { ["COLORTERM"] = "truecolor" }, -- default = nil,
    -- Developer configurations: Not meant for general override
    buffer_previewer_maker = require("telescope.previewers").buffer_previewer_maker,
    mappings = {
      n = { ["q"] = require("telescope.actions").close },
      i = { ["<esc>"] = require("telescope.actions").close },
    },
  },
  extensions_list = { "themes", "terms" },
  pickers = {
    -- live_grep = {
    --   additional_args = function()
    --     return { "-L" }
    --   end
    -- },
    buffers = {
      show_all_buffers = true,
      sort_lastused = true,
      -- theme = "dropdown",
      previewer = false,
      mappings = {
        i = {
          ["<c-d>"] = "delete_buffer",
        }
      }
    },
    find_files = {
      hidden = true,
      find_command = {'fd', '--type', 'f', '--hidden', '--follow', '--exclude', '.git'},
    }
  },
  extensions = {
    import = {
      -- Add imports to the top of the file keeping the cursor in place
      insert_at_top = true,
    },
    -- https://github.com/nvim-telescope/telescope-fzf-native.nvim
    -- fzf-native is a c port of fzf. It only covers the algorithm and
    -- implements few functions to support calculating the score.
    fzf = {
      fuzzy = true,                    -- false will only do exact matching
      -- override_generic_sorter = true,  -- override the generic sorter
      -- override_file_sorter = true,     -- override the file sorter
      -- case_mode = "smart_case",        -- or "ignore_case" or "respect_case"
      case_mode = "ignore_case",        -- or "ignore_case" or "respect_case"
    }
  }
}

local telescope_global = require("telescope")

telescope_global.load_extension('import')
telescope_global.load_extension('fzf')
-- require('telescope').load_extension("ag")

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
    -- We need to directly call CLI searcher "rg" to set max depth for searching in dirs
    find_command = { 'rg', '--files', '--no-ignore', '--hidden', '-g', '!.git', '--max-depth', '1' }
  })
end

function full_text_search_only_in_opened_buffers()
  telescope.live_grep({
    prompt_title = 'Find in opened buffers',
    -- layout_strategy = "horizontal",
    vimgrep_arguments = {
      -- "rg",
      -- "-L",
      -- "--color=never",
      -- "--no-heading",
      -- "--with-filename",
      -- "--line-number",
      -- "--column",
      -- "--smart-case",
      "ag",
      "--nocolor",
      "--noheading",
      -- "--numbers",
      "--column",
      "--smart-case",
      "--silent",
      "--vimgrep"
    },
    -- previewer = false,
    grep_open_files = true
  })
end

-- function find_word()
--   telescope.grep_string({
--     only_sort_text = true
--   })
-- end

local find_models = find_reource_in_dir("app/models")
local find_controllers = find_reource_in_dir("app/controllers")
local find_css = find_reource_in_dir("app/assets/stylesheets")
local find_js = find_reource_in_dir("app/assets/javascripts")
-- local find_components = find_reource_in_dir("app/components")
local find_view_components = find_reource_in_dir("app/view_components")
local find_components = find_reource_in_dir("app/components")
local find_views = find_reource_in_dir("app/views")
local find_i18n = find_reource_in_dir("config/locales/custom_updates")

-- Search files
-- vim.keymap.set('n', '<C-p>', telescope.find_files, { noremap = true })
vim.keymap.set('n', '<C-p>', find_files_wihout_preview, { noremap = true })
-- " Search sibling files in same directory as current file(with preview window)
vim.keymap.set('n', '<Leader>i', find_sibling_files, { noremap = true })
vim.keymap.set('n', 's', find_sibling_files, { noremap = true })

-- Full text search
-- vim.keymap.set('n', '<Leader>o', telescope.live_grep, {})
-- vim.keymap.set('n', '<Leader>p', full_text_search_wihout_preview, {})
vim.keymap.set('n', '<Leader>q', full_text_search_only_in_opened_buffers, {})
-- vim.keymap.set('n', '<Leader>q', Buffers, {})

-- Find in varios Rails projekt dirs
vim.keymap.set('n', '<Leader>m', find_models, {})
vim.keymap.set('n', '<Leader>c', find_controllers, {})
vim.keymap.set('n', '<Leader>j', find_js, {})
vim.keymap.set('n', '<Leader>s', find_css, {})
vim.keymap.set('n', '<Leader>f', find_view_components, {})
vim.keymap.set('n', '<Leader>k', find_components, {})
vim.keymap.set('n', '<Leader>d', find_views, {})
vim.keymap.set('n', '<Leader>b', find_i18n, {})
-- vim.keymap.set('n', '@', find_word, {})


-- Define a new highlight group for the border color
vim.cmd('highlight TelescopeBorder guifg=#efb993')
vim.cmd('highlight link TelescopeBorder FloatBorder')
vim.cmd('highlight link Directory Conditional')
-- Change highlith of match word
--
vim.cmd [[
  hi! link TelescopeMatching Type
]]
