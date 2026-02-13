require("neo-tree").setup({
  -- displays errors or warnings in the file, depending on the language server.
  enable_diagnostics = true,
  -- keeps Neo Tree visible if there are no more files open.
  close_if_last_window = true,
  --  displays Git change information.
  enable_git_status = true,
  use_popups_for_input = false,
  sort_case_insensitive = false,

  sources = { "filesystem", "buffers", "git_status", "document_symbols" },
  open_files_do_not_replace_types = { "terminal", "Trouble", "trouble", "qf", "Outline" },

  default_component_configs = {
    name = {
      use_popups_for_input = false,  -- Disable floating dialogs for renaming
    },
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

    icon = {
      folder_closed = "",
      folder_open = "",
      folder_empty = "",
      -- The next two settings are only a fallback, if you use nvim-web-devicons and configure default icons there
      -- then these will never be used.
      default = "*",
      highlight = "NeoTreeFileIcon"
    },
  },
  window = {
    width = 35,
    mappings = {
      ["x"] = "close_node",
      -- ['C'] = 'close_all_subnodes',
      --
      ["/"] = "none",

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
      -- ["<"] = "prev_source",
      -- [">"] = "next_source",
      ["<"] = "none",
      [">"] = "none",
    },
  },
  nesting_rules = {},
  filesystem = {
    bind_to_cwd = false,
    follow_current_file = { enabled = false },
    use_libuv_file_watcher = true,
    filtered_items = {
      visible = false, -- when true, they will just be displayed differently than normal items
      hide_dotfiles = false,
      hide_gitignored = false,
    }
  },
  never_show = { -- remains hidden even if visible is toggled to true, this overrides always_show
    ".DS_Store",
    "thumbs.db"
  },
  use_popups_for_input = false,
})

-- ======================== neo-tree mappings ===================================
-- Disable default Ctrl-\ mapping
vim.api.nvim_set_keymap("n", "<C-\\>", "<NOP>", {noremap = true, silent = true})

vim.keymap.set("n", "<C-\\>", function()
  local current_buf = vim.api.nvim_get_current_buf()
  
  if vim.b[current_buf].is_onediff_buffer or vim.b[current_buf].onediff_instance_id then
    local ok, onediff = pcall(require, "my_extensions.onediff")
    if ok then
      onediff.toggle_sidebar()
    else
      vim.cmd("Neotree toggle")
    end
  else
    vim.cmd("Neotree toggle")
  end
end, {noremap = true, silent = true, desc = "Toggle sidebar"})

vim.api.nvim_set_keymap("n", "<Leader>0", ":Neotree filesystem reveal<CR>", {noremap = true, silent = false})
vim.api.nvim_set_keymap("n", "=", ":Neotree filesystem reveal<CR>", {noremap = true, silent = false})


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
