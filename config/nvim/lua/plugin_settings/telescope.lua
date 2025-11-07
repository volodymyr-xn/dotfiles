local telescope_global = require("telescope")

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
      -- "ag",
      -- "--nocolor",
      -- "--noheading",
      -- "--numbers",
      -- "--column",
      -- "--smart-case",
      -- "--silent",
      -- "--vimgrep"
    },
    preview = {
      treesitter = {
        enable = {"javascript"},
        -- disable = { 'scss' }
      },
    },
    -- prompt_prefix = "   ",
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
  pickers = {
    -- live_grep = {
    --   additional_args = function()
    --     return { "-L" }
    --   end
    -- },
    buffers = {
      show_all_buffers = true,
      sort_lastused = true,
      ignore_current_buffer = true,
      -- theme = "dropdown",
      -- previewer = false,
      mappings = {
        i = {
          ["<c-d>"] = "delete_buffer",
        }
      }
    },
    find_files = {
      hidden = true,
      previewer = false,
      find_command = {'fd', '--type', 'f', '--hidden', '--follow', '--exclude', '.git'},
    },
    -- quickfix = {
    --   previewer = false
    -- }
  },
  extensions_list = { "themes", "terms" },
  extensions = {
    ["ui-select"] = {
      require("telescope.themes").get_dropdown { }
      -- pseudo code / specification for writing custom displays, like the one
      -- for "codeactions"
      -- specific_opts = {
      --   [kind] = {
      --     make_indexed = function(items) -> indexed_items, width,
      --     make_displayer = function(widths) -> displayer
      --     make_display = function(displayer) -> function(e)
      --     make_ordinal = function(e) -> string
      --   },
      --   -- for example to disable the custom builtin "codeactions" display
      --      do the following
      --   codeactions = false,
      -- }
    },
    -- import = {
    --   -- Add imports to the top of the file keeping the cursor in place
    --   insert_at_top = true,
    -- },
    -- https://github.com/nvim-telescope/telescope-fzf-native.nvim
    -- fzf-native is a c port of fzf. It only covers the algorithm and
    -- implements few functions to support calculating the score.
    fzf = {
      fuzzy = true,                    -- false will only do exact matching
      override_generic_sorter = true,  -- override the generic sorter
      override_file_sorter = true,     -- override the file sorter
      -- case_mode = "smart_case",        -- or "ignore_case" or "respect_case"
      case_mode = "ignore_case",        -- or "ignore_case" or "respect_case"
    }
  }
}
-- require('telescope').load_extension("ag")
-- telescope_global.load_extension('import')
telescope_global.load_extension('fzf')
telescope_global.load_extension("ui-select")

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

local function find_changed_files()
  telescope.git_status()
end

function find_resource_in_dir(dir)
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

function full_text_search_only_in_opened_buffers_fzf_version()
  vim.cmd[[ Buffers! ]]
end
-- function find_word()
--   telescope.grep_string({
--     only_sort_text = true
--   })
-- end

local find_models = find_resource_in_dir("app/models")
local find_controllers = find_resource_in_dir("app/controllers")
local find_css = find_resource_in_dir("app/assets/stylesheets")
local find_js = find_resource_in_dir("app/assets/javascripts")

local find_views = find_resource_in_dir("app/views")
local find_i18n = find_resource_in_dir("config/locales")

local components_dir = CustomFindFirstAvailableDir({'app/components', "app/view_components"})
local find_view_components = find_resource_in_dir(components_dir)
-- if (components_dir) then
vim.keymap.set('n', '<Leader>f', find_view_components, {})
-- end

-- Search files
-- vim.keymap.set('n', '<C-p>', telescope.find_files, { noremap = true })
vim.keymap.set('n', '<C-p>', find_files_wihout_preview, { noremap = true })
-- " Search sibling files in same directory as current file(with preview window)
vim.keymap.set('n', '<Leader>i', find_sibling_files, { noremap = true })
-- vim.keymap.set('n', 'R', telescope.grep_string, { noremap = true })


-- Full text search
-- vim.keymap.set('n', '<Leader>o', telescope.live_grep, {})
-- vim.keymap.set('n', '<Leader>p', full_text_search_wihout_preview, {})

-- Find changed files
vim.keymap.set('n', 'q', find_changed_files, {})
-- Buffer select
vim.api.nvim_set_keymap('n', '<Leader>q', ':Buffers!<CR>', {noremap = true})

-- vim.keymap.set('n', '<Leader>h', full_text_search_only_in_opened_buffers, {})
vim.keymap.set('n', '<Leader>x', telescope.current_buffer_fuzzy_find, {})

-- vim.keymap.set('n', '<Leader>h', full_text_search_only_in_opened_buffers_fzf_version, {})

vim.keymap.set('n', ',q', ":Tel<CR>", {})

-- Find in varios Rails projekt dirs
vim.keymap.set('n', '<Leader>m', find_models, {})
vim.keymap.set('n', '<Leader>c', find_controllers, {})
vim.keymap.set('n', '<Leader>j', find_js, {})
vim.keymap.set('n', '<Leader>s', find_css, {})
vim.keymap.set('n', '<Leader>d', find_views, {})
vim.keymap.set('n', '<Leader>b', find_i18n, {})



-- vim.keymap.set('n', '@', find_word, {})
-- local builtin = require('telescope.builtin')
-- vim.keymap.set('n', 'gt', builtin.tags, { desc = '[G]o to C[T]ags (telescope)', noremap = true })

-- It enables passing arguments to the grep command, rg examples:
-- foo → press <C-k> → "foo"  → "foo" -tmd
-- Only works if you set up the <C-k> mapping
--no-ignore foo
-- "foo bar" bazdir
-- "foo" --iglob **/bar/**
-- vim.keymap.set("n", "<leader>z", ":lua require('telescope').extensions.live_grep_args.live_grep_args()<CR>")


-- Define a new highlight group for the border color
vim.cmd('highlight TelescopeBorder guifg=#efb993')
vim.cmd('highlight link TelescopeBorder FloatBorder')
vim.cmd('highlight link Directory Conditional')
-- Change highlith of match word
--
vim.cmd [[
  hi! link TelescopeMatching Type
]]
