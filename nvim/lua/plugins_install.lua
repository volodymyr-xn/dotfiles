local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end

vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
   performance = {
    rtp = {
      disabled_plugins = {
        "2html_plugin",
        "tohtml",
        "getscript",
        "getscriptPlugin",
        "gzip",
        "logipat",
        "netrw",
        "netrwPlugin",
        "netrwSettings",
        "netrwFileHandlers",
        "matchit",
        "tar",
        "tarPlugin",
        "rrhelper",
        "spellfile_plugin",
        "vimball",
        "vimballPlugin",
        "zip",
        "zipPlugin",
        "tutor",
        "rplugin",
        "syntax",
        "synmenu",
        "optwin",
        "compiler",
        "bugreport",
        "ftplugin",
      },
    },
  },

  -- ============================================================
  -- Filetree & navigation
  -- ============================================================

  -- Filetree
  -- "scrooloose/nerdtree",
  -- TODO Replace nerdtree with fern
  -- "lambdalisue/fern.vim",

  -- Nerdtree like file exploer
  -- 'nvim-tree/nvim-tree.lua',

  {
    "nvim-neo-tree/neo-tree.nvim",
    cmd = { "Neotree" },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
    },
    config = function() require("plugin_settings.neo_tree") end,
  },

  -- Easily navigate between vim and tmux panes
  "christoomey/vim-tmux-navigator",

  -- Open in split select for NeoTree
  {
    's1n7ax/nvim-window-picker',
    name = 'window-picker',
    event = 'VeryLazy',
    version = '2.*',
    config = function()
      require'window-picker'.setup({
        hint = 'floating-big-letter',
             floating_big_letter = {
            -- window picker plugin provides bunch of big letter fonts
            -- fonts will be lazy loaded as they are being requested
            -- additionally, user can pass in a table of fonts in to font
            -- property to use instead

            font = 'ansi-shadow', -- ansi-shadow |
        },
      })
    end,
  },

  -- ============================================================
  -- Fuzzy finders / pickers
  -- ============================================================

  {
    "dmtrKovalenko/fff.nvim",
    build = ':lua require("fff.download").download_or_build_binary()',
  },

  "ibhagwan/fzf-lua",

  -- FZF integration
  {
    "junegunn/fzf.vim",
    dependencies = { 'junegunn/fzf' },
    config = function() require("plugin_settings.fzf") end,
  },

  -- Lua port of FZF for neovim
  -- (https://github.com/ibhagwan/fzf-lua)

  {
    'nvim-telescope/telescope.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    commit = "cb3f98d935842836cc115e8c9e4b38c1380fbb6b",
    config = function() require("plugin_settings.telescope") end,
  },
  "nvim-telescope/telescope-ui-select.nvim",
  -- Enabled live grep in dir
  "nvim-telescope/telescope-live-grep-args.nvim",

  {
    'nvim-telescope/telescope-fzf-native.nvim',
    --build = 'make'
    build = 'cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release -DCMAKE_POLICY_VERSION_MINIMUM=3.5 && cmake --build build --config Release && cmake --install build --prefix build'
  },
  -- An extension for telescope.nvim that allows you to import modules faster
  -- based on what you've already imported in your project.
  -- "piersolenski/telescope-import.nvim",
  -- 'piersolenski/telescope-import.nvim',

  -- ============================================================
  -- Git
  -- ============================================================

  -- Show changed lines from git
  -- "airblade/vim-gitgutter",
  -- gitsigns.nvim spec is declared below with its config

  -- Git integration
  {
    "tpope/vim-fugitive",
    cmd = { "G", "Git", "Gdiffsplit", "Gread", "Gwrite", "Ggrep", "Glgrep", "Gclog", "Gllog", "Gedit", "Gsplit", "Gvsplit", "Gtabedit", "Gpedit", "GBrowse" },
    config = function() require("plugin_settings.fugitive") end,
  },
  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewToggleFiles", "DiffviewFocusFiles", "DiffviewFileHistory", "DiffviewRefresh" },
    config = function() require("plugin_settings.diffview") end,
  },
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    config = function() require("plugin_settings.gitsigns") end,
  },

  -- A plugin to visualise and resolve merge conflicts in neovim
  -- 'akinsho/git-conflict.nvim',
  -- 'rhysd/conflict-marker.vim',

  -- ============================================================
  -- LSP & completion
  -- ============================================================

  -- Portable package manager for Neovim that runs everywhere Neovim runs.
  -- easily install and manage LSP servers, DAP servers, linters, and
  -- formatters.
  { "williamboman/mason.nvim", cmd = { "Mason", "MasonInstall", "MasonInstallAll", "MasonUpdate", "MasonUninstall", "MasonUninstallAll", "MasonLog" } },
  -- mason-lspconfig bridges mason.nvim with the lspconfig plugin - making it
  -- easier to use both plugins together.
  "williamboman/mason-lspconfig.nvim",

  -- Configs for the Nvim LSP client (:help lsp).(Quickstart configs for Nvim LSP )
  {
    "neovim/nvim-lspconfig",
    dependencies = { "williamboman/mason.nvim", "williamboman/mason-lspconfig.nvim" },
    config = function() require("plugin_settings.lsp_config") end,
  },

  -- A neovim plugin that preview code with LSP code actions applied.
  -- actions-preview and cmp sources/icons are loaded as deps of nvim-cmp below.
  -- {
  --   "tzachar/cmp-fuzzy-buffer",
  --   dependencies = {
  --     "tzachar/fuzzy.nvim"
  --   }
  -- },

  -- Autocomplte plugin
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "aznhe21/actions-preview.nvim",
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-cmdline",
      "onsails/lspkind.nvim",
    },
    config = function() require("plugin_settings.nvim_cmp") end,
  },
  -- "lukas-reineke/cmp-rg",

  -- Alternative fast completion plugin
  -- {
  --   'saghen/blink.cmp',
  --   commit = "52cd2aa"
  -- },

  -- "github/copilot.vim",
  -- 'zbirenbaum/copilot.lua',
  -- "zbirenbaum/copilot-cmp",
  -- "ray-x/cmp-treesitter",

  -- Utility functions for getting diagnostic status and progress messages from
  -- LSP servers, for use in the Neovim statusline
  "nvim-lua/lsp-status.nvim",

  "ray-x/navigator.lua",

  -- Old and broken
  -- Snippets
  -- "MarcWeber/vim-addon-mw-utils",
  {
    "L3MON4D3/LuaSnip",
    config = function() require("plugin_settings.luasnip") end,
  },
  'saadparwaiz1/cmp_luasnip',
  -- "rafamadriz/friendly-snippets",

  -- VSCode bulb bulb for neovim's built-in LSP.
  -- 'kosayoda/nvim-lightbulb',

  -- A lightweight LSP plugin based on Neovim's built-in LSP with a highly
  -- performant UI.
  -- 'glepnir/lspsaga.nvim',

  -- Neovim setup for init.lua and plugin development with full signature help,
  -- docs and completion for the nvim lua API.
  -- 'folke/neodev.nvim',

  -- ============================================================
  -- Treesitter
  -- ============================================================

  "JoosepAlviste/nvim-ts-context-commentstring",

  {
    "nvim-treesitter/nvim-treesitter",
    config = function() require("plugin_settings.treesitter") end,
  },

  -- {
  --   "nvim-treesitter/nvim-treesitter-context"
  -- },

  -- Use treesitter to autoclose and autorename html tag
  -- "windwp/nvim-ts-autotag",

  -- ============================================================
  -- Syntax / filetype
  -- ============================================================

  { "tpope/vim-haml", ft = { "haml", "eruby" } },

  -- Ruby on Rails power tool
  -- This is a massive (in a good way) Vim plugin for editing Ruby on Rails applications.
  -- Partial and concern extraction. In a view, :Extract {file} replaces the
  -- desired range (typically selected in visual line mode) with render '{file}',
  -- which is automatically created with your content. In a model or controller, a
  -- concern is created, with the appropriate include declaration left behind.
  -- :help rails-:Extract
  {
    "tpope/vim-rails",
    ft = { "ruby", "eruby", "haml", "yaml" },
    config = function() require("plugin_settings.vim_rails") end,
  },

  -- Better rspec syntax highlighting for Vim
  { "keith/rspec.vim", ft = "ruby" },

  -- Ruby syntax highlighting
  { "vim-ruby/vim-ruby", ft = "ruby" },

  -- Vim highlighting & completion for MiniTest
  { "sunaku/vim-ruby-minitest", ft = "ruby" },

  -- "weizheheng/ror.nvim",
  -- "jonsmithers/vim-html-template-literals",

  -- CSS3 syntax support
  { "hail2u/vim-css3-syntax", ft = { "css", "scss" } },

  -- Crystal syntax support
  { "vim-crystal/vim-crystal", ft = "crystal" },

  -- Improved JavaScript syntax
  { "pangloss/vim-javascript", ft = { "javascript", "javascriptreact" } },

  -- JSX syntax support
  -- "mxw/vim-jsx",

  -- Brewfile syntax highlighting
  { "bfontaine/brewfile.vim", ft = "ruby" },

  -- Auto close (X)HTML tags
  -- "alvan/vim-closetag",

  -- Shows yaml path under cursor,
  -- allows to search by YAML key
  { "Einenlum/yaml-revealer", ft = { "yaml", "yml" } },

  -- Better yaml
  {
    "cuducos/yaml.nvim",
    ft = { "yaml", "yml" },
    -- <Leader>` is owned by keymappings/terminal.lua (tmux.send_file); the
    -- yaml.nvim mapping inside plugin_settings/yaml_nvim.lua was already
    -- dead code in the eager config. ft trigger only.
    config = function() require("plugin_settings.yaml_nvim") end,
  },

  -- Better yaml folding
  -- "pedrohdz/vim-yaml-folds",

  -- AppArmor syntax highlight
  -- 'ClockworkNet/vim-apparmor')

  -- Improved nginx vim plugin (incl. syntax highlighting)
  -- "chr4/nginx.vim",

  -- JSON highlight
  -- "elzr/vim-json",

  -- Syntax highlighting and filetype detection for systemd unit files
  { "wgwoods/vim-systemd-syntax", ft = "systemd" },

  --- Syntax highlighting for Nix configs
  -- "LnL7/vim-nix",

  -- Better markdown support
  -- "plasticboy/vim-markdown",

  -- GTK Blueprint syntax
  -- "thetek42/vim-blueprint-syntax",

  -- Emmet
  {
    "mattn/emmet-vim",
    -- TODO: write issue on github regarding bug on main
    commit = "3fb2f63799e1922f7647ed9ff3b32154031a76ee",
    ft = { "html", "css", "scss", "sass", "javascriptreact", "typescriptreact", "vue", "eruby", "haml", "xml" },
    config = function() require("plugin_settings.emmet") end,
  },
  -- LSP for emmet
  -- "olrtg/nvim-emmet",

  {
    "OXY2DEV/markview.nvim",
    ft = { "markdown", "Avante", "codecompanion" },
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function() require("plugin_settings.markview") end,
  },

  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    ft = { "markdown" },
    build = function() vim.fn["mkdp#util#install"]() end,
  },

  -- ============================================================
  -- Editing (motions, textobjs, pairs, surround, comments)
  -- ============================================================

  {
    "echasnovski/mini.ai",
    version = "*",
    config = function() require("plugin_settings.mini_ai") end,
  },

  -- Alternative plugin:
  -- "preservim/nerdcommenter",
  -- At the time of installing (2024) only tpope/vim-commentary
  -- works correcly for commenting erb files
  "tpope/vim-commentary",

  -- Enable repeating supported plugin maps with '.'
  "tpope/vim-repeat",

  -- 'alvan/vim-closetag',

  -- Create your own text objects
  "kana/vim-textobj-user",

  -- Make text objects with various ruby block structures.
  -- TODO: replace with NEOVIM equvivalent
  -- "rhysd/vim-textobj-ruby",
  {
    "chrisgrieser/nvim-various-textobjs",
    event = "VeryLazy",
    opts = {
      keymaps = {
        useDefaults = true
      }
    }
  },

  "michaeljsmith/vim-indent-object",

  -- Automaticaly add end in ruby scrips
  { "tpope/vim-endwise", ft = { "ruby", "lua", "vim", "sh", "zsh", "elixir", "crystal" } },

  -- quoting/parenthesizing made simple
  -- "tpope/vim-surround",

  -- Provides additional text objects
  -- Example:
  -- ci* - change inside star
  -- va| - visually select around pipe
  -- ci_ - change inside underscore
  -- ca/aa/Ia/Aa  - change inside function/method argument
  -- "wellle/targets.vim",

  -- Provides insert mode auto-completion for quotes, parens, brackets
  -- TODO: Replace of NEOVIM equvivalent
  -- "Raimondi/delimitMate",

  -- Multiple cursors
  "mg979/vim-visual-multi",

  -- Auto close quotes, parenthesiz, etc
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = function() require("plugin_settings.nvim_autopairs") end,
  },

  {
    "andymass/vim-matchup",
    event = { "BufReadPost", "BufNewFile" },
    config = function() require("plugin_settings.vim_matchup") end,
  },
  -- Alternative plugin
  -- "echasnovski/mini.pairs",

  -- unimpaired.vim: Pairs of handy bracket mappings
  { "tpope/vim-unimpaired", event = "VeryLazy" },

  -- Switch between multiline and signleline code
  {
    "AndrewRadev/splitjoin.vim",
    -- <Leader>7 / <Leader>8 are owned by keymappings/windows.lua
    -- (Go to tab N); they were dead splitjoin triggers in both the eager
    -- and lazy configs. Trigger on gS/gJ only.
    keys = { "gS", "gJ" },
    config = function() require("plugin_settings.splitjoin") end,
  },

  -- Treesitter-aware split/join (smarter than splitjoin.vim)
  {
    "Wansmer/treesj",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    cmd = { "TSJToggle", "TSJSplit", "TSJJoin" },
    keys = { { "<leader>M", desc = "Toggle split/join" } },
    config = function() require("plugin_settings.treesj") end,
  },

  -- Switch between different things
  -- 'AndrewRadev/switch.vim',

  -- Highlight matching HTML tag
  -- TODO: check how good is performance
  -- 'leafOfTree/vim-matchtag',

  {
    "chrisgrieser/nvim-spider",
    config = function() require("plugin_settings.nvim_spider") end,
  },

  {
    "kylechui/nvim-surround",
    version = "*", -- Use for stability; omit to use `main` branch for the latest features
    event = "VeryLazy",
    config = function()
      require("nvim-surround").setup({
        -- Configuration here, or leave empty to use defaults
      })
    end
  },

  -- "ggandor/leap.nvim",

  {
    "folke/flash.nvim",
    event = "VeryLazy",
    config = function() require("plugin_settings.flash") end,
  },

  -- ============================================================
  -- UI (statusline, tabline, scrollbar, colors, highlights)
  -- ============================================================

  -- Provides devicons
  -- Requires nerdfont: (https://www.nerdfonts.com/)
  "nvim-tree/nvim-web-devicons",

  "echasnovski/mini.icons",
  { "echasnovski/mini.extra", version = "*" },

  -- Base16 color schemes
  -- "Mofiqul/dracula.nvim",
  -- "folke/tokyonight.nvim",
  -- "rose-pine/neovim",
  -- "EdenEast/nightfox.nvim",
  "catppuccin/nvim",
  -- "tinted-theming/base16-vim",
  -- "ellisonleao/gruvbox.nvim",
  -- "rebelot/kanagawa.nvim",
  -- "dracula/vim",
  -- "sainnhe/sonokai",

  -- Dracula color scheme
  -- 'dracula/vim',

  -- Automatically highlighting other uses of the current word under the cursor
  -- "RRethy/vim-illuminate",
  -- Alternative to vim-illuminate
  -- "tzachar/local-highlight.nvim",

  -- Statusline
  {
    "nvim-lualine/lualine.nvim",
    config = function() require("plugin_settings.lualine") end,
  },
  -- Alternative statusline
  -- "rebelot/heirline.nvim",

  -- Highligh color codes
  -- "lilydjwg/colorizer", -- Old plugin, works OK
  {
    'brenoprata10/nvim-highlight-colors',
    event = { "BufReadPost", "BufNewFile" },
    config = function() require("plugin_settings.colorizer") end,
  },
  -- "NvChad/nvim-colorizer.lua",
  -- A high-performance color highlighter for Neovim which has no
  -- external dependencies! Written in performant Luajit.
  -- "norcalli/nvim-colorizer.lua",

  -- Tabline
  {
    "akinsho/bufferline.nvim",
    event = "VeryLazy",
    config = function() require("plugin_settings.tabline_bufferline") end,
  },

  -- Show scrollbar for VIM buffer(SUPER COOL!)
  {
    'petertriho/nvim-scrollbar',
    event = { "BufReadPost", "BufNewFile" },
    config = function() require("plugin_settings.nvim_scrollview") end,
  },
  { "kevinhwang91/nvim-hlslens", keys = { "/", "?", "n", "N", "*", "#", "g*", "g#" } },

  -- Indent line guides
  -- "lukas-reineke/indent-blankline.nvim",

  -- Visual glow feedback for undo, redo, yank, paste, and search
  {
    "y3owk1n/undo-glow.nvim",
    version = "*",
    event = "VeryLazy",
    config = function() require("plugin_settings.undo_glow") end,
  },

  {
    "folke/snacks.nvim",
    lazy = false,
    priority = 1000,
    opts = {},
  },

  --{
  --  "folke/snacks.nvim",
  --  ---@type snacks.Config
  --  opts = {
  --    explorer = {
  --      -- your explorer configuration comes here
  --      -- or leave it empty to use the default settings
  --      -- refer to the configuration section below
  --    },
  --    picker = {
  --      sources = {
  --        explorer = {
  --          -- your explorer picker configuration comes here
  --          -- or leave it empty to use the default settings
  --        }
  --      }
  --    }
  --  }
  --}

  -- ======== Tesing area ====================
  -- "rcarriga/nvim-notify",
  -- "stevearc/dressing.nvim",

  -- ============================================================
  -- Search / quickfix / lint / format
  -- ============================================================

  -- Global search by ack cli util
  -- "mileszs/ack.vim",

  -- Delete entries from quickfix
  -- "stefandtw/quickfix-reflector.vim",

  -- Delete entries from quickfix (alt)
  { "itchyny/vim-qfedit", ft = "qf" },

  -- Linting
  -- "w0rp/ale",

  -- TODO Alternative linting plugin(Consider to switch in future)
  -- "neomake/neomake",

  -- Run linters and formaters as fake LSP
  -- 'jose-elias-alvarez/null-ls.nvim',
  -- Linting syntastic like plugin
  {
    'mfussenegger/nvim-lint',
    event = { "BufReadPost", "BufNewFile", "BufWritePost" },
    config = function() require("plugin_settings.nvim_lint") end,
  },

  -- Formating framework (like null-ls, syntastic, etc)
  {
    "stevearc/conform.nvim",
    event = { "BufReadPre", "BufNewFile" },
    cmd = { "ConformInfo" },
    config = function() require("plugin_settings.conform_formater") end,
  },

  -- Very cool search & replace plugin similar to Atom
  -- "MagicDuck/grug-far.nvim",

  -- A collection of improvements for the quickfix buffer
  -- "stevearc/qf_helper.nvim",

  -- 'MunifTanjim/prettier.nvim',

  -- ============================================================
  -- Test / terminal
  -- ============================================================

  -- Run various tests from vim
  {
    "janko-m/vim-test",
    cmd = { "TestNearest", "TestFile", "TestSuite", "TestLast", "TestVisit" },
    config = function() require("plugin_settings.vim_test") end,
  },

  -- Allows vim to communicate and run commands in tmux
  "benmills/vimux",

  -- Make terminal vim and tmux work better together.
  { "tmux-plugins/vim-tmux-focus-events", event = "VeryLazy" },

  -- ============================================================
  -- AI
  -- ============================================================

  -- Use local Ollama AI in VIM
  {
    "David-Kunz/gen.nvim",
    cmd = "Gen",
    keys = { { "<leader>q", ":Gen<CR>", mode = "v", desc = "Gen AI prompts" } },
    config = function() require("plugin_settings.gen_nvim") end,
  },

  -- Cursor like code completion
  -- {
  --   "yetone/avante.nvim",
  --   event = "VeryLazy",
  --   lazy = false,
  --   version = false, -- Set this to "*" to always pull the latest release version, or set it to false to update to the latest code changes.
  --   opts = {
  --     -- add any opts here
  --     -- for example
  --     provider = "openai",
  --     openai = {
  --       endpoint = "https://api.openai.com/v1",
  --       model = "gpt-4o", -- your desired model (or use gpt-4o, etc.)
  --       timeout = 30000, -- timeout in milliseconds
  --       temperature = 0, -- adjust if needed
  --       max_tokens = 4096,
  --     },
  --   },
  --   -- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
  --   build = "make",
  --   -- build = "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false" -- for windows
  --   dependencies = {
  --     "stevearc/dressing.nvim",
  --     "nvim-lua/plenary.nvim",
  --     "MunifTanjim/nui.nvim",
  --     --- The below dependencies are optional,
  --     "echasnovski/mini.pick", -- for file_selector provider mini.pick
  --     "nvim-telescope/telescope.nvim", -- for file_selector provider telescope
  --     "hrsh7th/nvim-cmp", -- autocompletion for avante commands and mentions
  --     "ibhagwan/fzf-lua", -- for file_selector provider fzf
  --     "nvim-tree/nvim-web-devicons", -- or echasnovski/mini.icons
  --     "zbirenbaum/copilot.lua", -- for providers='copilot'
  --     {
  --       -- support for image pasting
  --       "HakonHarnes/img-clip.nvim",
  --       event = "VeryLazy",
  --       opts = {
  --         -- recommended settings
  --         default = {
  --           embed_image_as_base64 = false,
  --           prompt_for_file_name = false,
  --           drag_and_drop = {
  --             insert_mode = true,
  --           },
  --           -- required for Windows users
  --           use_absolute_path = true,
  --         },
  --       },
  --     },
  --     {
  --       -- Make sure to set this up properly if you have lazy=true
  --       'MeanderingProgrammer/render-markdown.nvim',
  --       opts = {
  --         file_types = { "markdown", "Avante" },
  --       },
  --       ft = { "markdown", "Avante" },
  --     },
  --   },
  -- },

  -- For some reason right now(24.01.2025) this plugin works very slowly
  -- with ollama if you compare it to other similar plugins like gen.nvim
  -- Try it again at the end of 2025 or in 2026 year
  -- {
  --   "olimorris/codecompanion.nvim",
  --   dependencies = {
  --     "nvim-lua/plenary.nvim",
  --     "nvim-treesitter/nvim-treesitter",
  --   },
  --   config = true
  -- },

  -- {
  --   "huynle/ogpt.nvim",
  --   event = "VeryLazy",
  --   config = function()
  --     require("ogpt").setup()
  --   end,
  --   dependencies = {
  --     "MunifTanjim/nui.nvim",
  --     "nvim-lua/plenary.nvim",
  --     "nvim-telescope/telescope.nvim"
  --   }
  -- },

  -- "coder/claudecode.nvim"

  -- {
  --   "coder/claudecode.nvim",
  --   dependencies = { "folke/snacks.nvim" },
  --   config = true,
  --   terminal_cmd = "~/.claude/local/claude",
  --   keys = {
  --     { "<leader>a", nil, desc = "AI/Claude Code" },
  --     { "<leader>ac", "<cmd>ClaudeCode<cr>", desc = "Toggle Claude" },
  --     { "<leader>af", "<cmd>ClaudeCodeFocus<cr>", desc = "Focus Claude" },
  --     { "<leader>ar", "<cmd>ClaudeCode --resume<cr>", desc = "Resume Claude" },
  --     { "<leader>aC", "<cmd>ClaudeCode --continue<cr>", desc = "Continue Claude" },
  --     { "<leader>am", "<cmd>ClaudeCodeSelectModel<cr>", desc = "Select Claude model" },
  --     { "<leader>ab", "<cmd>ClaudeCodeAdd %<cr>", desc = "Add current buffer" },
  --     { "<leader>as", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send to Claude" },
  --     {
  --       "<leader>as",
  --       "<cmd>ClaudeCodeTreeAdd<cr>",
  --       desc = "Add file",
  --       ft = { "NvimTree", "neo-tree", "oil", "minifiles", "netrw" },
  --     },
  --     -- Diff management
  --     { "<leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Accept diff" },
  --     { "<leader>ad", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Deny diff" },
  --   },
  --   opts = {
  --     terminal = {
  --       provider = "none", -- no UI actions; server + tools remain available
  --     },
  --   },
  -- },

  -- ============================================================
  -- Outline / keymap helpers / misc
  -- ============================================================

  -- Show methods in file in sidebar(Has nice navigaton)
  {
    "stevearc/aerial.nvim",
    cmd = { "AerialToggle", "AerialOpen", "AerialClose", "AerialNext", "AerialPrev" },
    keys = { { "<leader>z", "<cmd>AerialToggle!<CR>", desc = "Toggle aerial outline" } },
    config = function() require("plugin_settings.aerial") end,
  },

  -- Use both plugins for outline
  -- Show methods in file in sidebar (Has nice highlight)
  {
    'hedyhli/outline.nvim',
    cmd = { "Outline", "OutlineOpen", "OutlineClose", "OutlineFocus", "OutlineFocusOutline" },
    dependencies = {
      'epheien/outline-treesitter-provider.nvim'
    },
    config = function() require("plugin_settings.outline") end,
  },

  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      triggers = {
        { "<leader>", mode = { "n", "v" } },
        { "s", mode = { "n" } },
        { "<C-w>", mode = { "n" } },
      },
      spec = {
        { "s", group = "navigate/search" },
        { "<C-w>", group = "windows" },
      },
    },
    keys = {
      {
        "<leader>?",
        function()
          require("which-key").show({ global = false })
        end,
        desc = "Buffer Local Keymaps (which-key)",
      },
    },
  },

  -- Measure startuptime
  { "dstein64/vim-startuptime", cmd = "StartupTime" },

  -- ============================================================
  -- Notes / wishlist (kept verbatim)
  -- ============================================================

  -- {
  --   "ray-x/go.nvim",
  --   dependencies = {  -- optional packages
  --     "ray-x/guihua.lua",
  --     "neovim/nvim-lspconfig",
  --     "nvim-treesitter/nvim-treesitter",
  --   },
  --   config = function()
  --     require("go").setup()
  --   end,
  --   event = {"CmdlineEnter"},
  --   ft = {"go", 'gomod'},
  --   build = ':lua require("go.install").update_all_sync()' -- if you need to install/update all binaries
  -- },

  -- ============= CURRENT EXPERIMENTAL PLUGINS ======================

  ----------------- NEXT IN LINE ========================
  -- "folke/trouble.nvim",

  -- A tree like view for symbols in Neovim using the Language Server Protocol.
  -- Supports all your favourite languages.
  -- 'simrat39/symbols-outline.nvim'
  -- Easily navigate between related files
  -- 'rgroli/other.nvim'
  -- Run various commands with Telescope
  -- 'octarect/telescope-menu.nvim'
  -- Like other.nvim but using telescope
  -- 'otavioschwanck/telescope-alternate.nvim'

  -- ============= TRY THIS PLUGINS IN FUTURE ======================
  -- 🚦 A pretty diagnostics, references, telescope
  -- results, quickfix and location list to help you solve all the trouble your
  -- code is causing.
  -- folke/trouble.nvim
  -- kevinhwang91/nvim-hlslens
  -- kevinhwang91/nvim-ufo
  --
  -- Easy navigation like EasyMotion.vim
  -- 'phaazon/hop.nvim/'
  -- folke/noice.nvim
  -- 'm-demare/hlargs.nvim'
})
