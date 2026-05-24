local telescope_global = require("telescope")
local telescope_actions = require("telescope.actions")

-- Send results to quickfix in one keystroke. Default <C-q> populates the
-- qflist but leaves the picker focused on top of it, so the qflist is
-- invisible until a second key closes telescope — feels like <C-q> "needs
-- two presses". smart_send_to_qflist already closes the picker internally,
-- so just open the qflist after it runs to land focus there in one press.
-- local function send_to_qflist_and_focus(prompt_bufnr)
--   telescope_actions.smart_send_to_qflist(prompt_bufnr)
--   vim.cmd("copen")
-- end

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
    -- git_status = {
    --   layout_config = {
    --     width = 99,
    --   },
    -- },
    file_sorter = require("telescope.sorters").get_fzy_sorter,
    generic_sorter = require("telescope.sorters").get_fzy_sorter,
    -- file_previewer = require("telescope.previewers").vim_buffer_cat.new,
    -- grep_previewer = require("telescope.previewers").vim_buffer_vimgrep.new,
    -- qflist_previewer = require("telescope.previewers").vim_buffer_qflist.new,
    file_ignore_patterns = { "node_modules", "%.git/" },
    -- path_display = { "truncate" },
    winblend = 0,
    border = {},
    borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
    color_devicons = true,
    set_env = { ["COLORTERM"] = "truecolor" }, -- default = nil,
    -- Developer configurations: Not meant for general override
    buffer_previewer_maker = require("telescope.previewers").buffer_previewer_maker,
    mappings = {
      n = {
        ["q"] = telescope_actions.close,
        -- ["<C-q>"] = send_to_qflist_and_focus,
      },
      i = {
        ["<esc>"] = telescope_actions.close,
        -- ["<C-q>"] = send_to_qflist_and_focus,
        -- readline-style navigation in the prompt
        ["<C-a>"] = function()
          vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Home>", true, false, true), "i", false)
        end,
        ["<C-e>"] = function()
          vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<End>", true, false, true), "i", false)
        end,
        ["<C-f>"] = function()
          vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-Left>", true, false, true), "i", false)
        end,
        ["<C-b>"] = function()
          vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-Right>", true, false, true), "i", false)
        end,
      },
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
telescope_global.load_extension("live_grep_args")



-- Define a new highlight group for the border color
vim.cmd('highlight TelescopeBorder guifg=#efb993')
vim.cmd('highlight link TelescopeBorder FloatBorder')
vim.cmd('highlight link Directory Conditional')
-- Change highlith of match word
--
vim.cmd [[
  hi! link TelescopeMatching Type
]]
