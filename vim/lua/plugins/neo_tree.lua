require("neo-tree").setup({
  use_popups_for_input = false,
  default_component_configs = {
    container = {
      enable_character_fade = true
    },
    git_status = {
      symbols = {
        -- Change type
        added     = "✚",
        deleted   = "✖",
        modified  = "",
        renamed   = "",
        -- Status type
        untracked = "*",
        ignored   = "",
        unstaged  = "",
        staged    = "",
        conflict  = "",
      }
    },
  },
  window = {
    mappings = {
      ["x"] = "close_node",
      -- ['C'] = 'close_all_subnodes',
      ["a"] = {
        "add",
        -- this command supports BASH style brace expansion ("x{a,b,c}" -> xa,xb,xc). see `:h neo-tree-file-actions` for details
        -- some commands may take optional config options, see `:h neo-tree-mappings` for details
        config = {
          show_path = "none" -- "none", "relative", "absolute"
        }
      },
      ["r"] = {
        "rename",
        config = {
          show_path = "relative" -- "none", "relative", "absolute"
        }
      },
      ["y"] = "copy_to_clipboard",
      -- ["x"] = "cut_to_clipboard",
      ["p"] = "paste_from_clipboard",
      -- ["c"] = "copy", -- takes text input for destination, also accepts the optional config.show_path option like "add":
      ["c"] = {
        "copy",
        config = {
          show_path = "relative" -- "none", "relative", "absolute"
        }
      },
      -- takes text input for destination, also accepts the optional config.show_path option like "add".
      ["m"] = {
        "move",
        config = {
          show_path = "relative" -- "none", "relative", "absolute"
        }
      },
      ["q"] = "close_window",
      ["R"] = "refresh",
      ["?"] = "show_help",
      ["<"] = "prev_source",
      [">"] = "next_source",
    },
  },
  nesting_rules = {},
  filesystem = {
    filtered_items = {
      visible = false, -- when true, they will just be displayed differently than normal items
      hide_dotfiles = false,
      hide_gitignored = false,
    }
  },
  never_show = { -- remains hidden even if visible is toggled to true, this overrides always_show
  ".DS_Store",
  "thumbs.db"
  }
})

-- ======================== neo-tree mappings ===================================
-- Disable default Ctrl-\ mapping
vim.api.nvim_set_keymap("n", "<C-\\>", "<NOP>", {noremap = true, silent = true})

-- Toggle NvimTree
vim.api.nvim_set_keymap("n", "<C-\\>", ":Neotree toggle<CR>", {noremap = true, silent = true})
vim.api.nvim_set_keymap("n", "<Leader>0", ":Neotree filesystem reveal<CR>", {noremap = true, silent = false})


--
-- vim.cmd('highlight! NeoTreeGitAdded guifg=#ffffff gui=bold')
vim.cmd('hi! link NeoTreeGitAdded Type ')
vim.cmd('hi! link NeoTreeGitUntracked Type')
vim.cmd('hi! link NeoTreeGitModified Type')
-- NeoTreeGitAdded
-- NeoTreeGitConflict
-- NeoTreeGitDeleted
-- NeoTreeGitIgnored
-- NeoTreeGitModified
-- NeoTreeGitUntracked
