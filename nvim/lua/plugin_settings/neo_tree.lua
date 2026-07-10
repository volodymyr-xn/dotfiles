local tmux = require("functions.tmux")
local fs_commands = require("neo-tree.sources.filesystem.commands")
local renderer = require("neo-tree.ui.renderer")

-- Single left click: move the cursor to the clicked row (with mousemodel=extend
-- the cursor may still sit on the previous row when this fires), then open a
-- file in a buffer and hand focus back to the tree, or toggle a directory in
-- place. Mirrors the <Tab> mapping's open + `wincmd p` so browsing stays in the
-- sidebar. The force-save records the clicked row so neo-tree's restore (run
-- when focus re-enters the tree, or after a toggle re-render) keeps the cursor
-- on the clicked row instead of snapping it back to the previous one.
local function open_on_single_click(state)
  local mouse = vim.fn.getmousepos()

  if mouse.winid ~= state.winid or mouse.line < 1 then
    return
  end

  local moved = pcall(vim.api.nvim_win_set_cursor, state.winid, { mouse.line, 0 })

  if not moved then
    return
  end

  local node = state.tree:get_node()

  if not node then
    return
  end

  renderer.position.save(state, true)

  if node.type == "directory" then
    fs_commands.toggle_node(state)
  else
    fs_commands.open(state)
    vim.cmd("wincmd p")
  end
end

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
      -- Single left click: open file in a buffer, toggle a directory.
      ["<LeftRelease>"] = open_on_single_click,
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
      ["P"] = { "toggle_preview", config = { use_float = true } },
      ["<Tab>"] = function(state)
        local node = state.tree:get_node()
        if node.type == "file" then
          fs_commands.open(state)
          vim.cmd("wincmd p")
        end
      end,
      ["`"] = function(state)
        local node = state.tree:get_node()
        local filepath = vim.fn.fnamemodify(node:get_id(), ":.")

        CopyToClipboardAndNotify(filepath)
      end,
      ["<Leader>`"] = function(state)
        local node = state.tree:get_node()
        tmux.send_path(vim.fn.fnamemodify(node:get_id(), ":."))
      end,
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

-- neo-tree keymaps live in keymappings/files.lua so they exist at startup
-- and trigger neo-tree's `cmd` lazy-load on first use.


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
