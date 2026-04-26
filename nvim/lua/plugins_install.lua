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
  -- Filetree
  -- "scrooloose/nerdtree",
  -- TODO Replace nerdtree with fern
  -- "lambdalisue/fern.vim",

  -- Nerdtree like file exploer
  -- 'nvim-tree/nvim-tree.lua',

  {
  "nvim-neo-tree/neo-tree.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
    }
  },

  -- Provides devicons
  -- Requires nerdfont: (https://www.nerdfonts.com/)
  "nvim-tree/nvim-web-devicons",

  "echasnovski/mini.icons",
  { "echasnovski/mini.pick", version = "*" },
  { "echasnovski/mini.extra", version = "*" },
  { "echasnovski/mini.ai", version = "*" },
  {
    "dmtrKovalenko/fff.nvim",
    build = ':lua require("fff.download").download_or_build_binary()',
  },

  "ibhagwan/fzf-lua",

  -- Alternative plugin:
  -- "preservim/nerdcommenter",
  -- At the time of installing (2024) only tpope/vim-commentary
  -- works correcly for commenting erb files
  "tpope/vim-commentary",
  "JoosepAlviste/nvim-ts-context-commentstring",

  "tpope/vim-haml",

  -- Linting
  -- "w0rp/ale",

  -- TODO Alternative linting plugin(Consider to switch in future)
  -- "neomake/neomake",

  -- Enable repeating supported plugin maps with '.'
  "tpope/vim-repeat",

  -- 'alvan/vim-closetag',

  -- FZF integration
  {
    "junegunn/fzf.vim",
    dependencies = { 'junegunn/fzf' }
  },

  -- Lua port of FZF for neovim
  -- (https://github.com/ibhagwan/fzf-lua)

  {
    'nvim-telescope/telescope.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    commit = "cb3f98d935842836cc115e8c9e4b38c1380fbb6b"
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

  -- Show changed lines from git
  -- "airblade/vim-gitgutter",
  -- TODO: Consider switch to
  'lewis6991/gitsigns.nvim',

  -- Ruby on Rails power tool
  -- This is a massive (in a good way) Vim plugin for editing Ruby on Rails applications.
  -- Partial and concern extraction. In a view, :Extract {file} replaces the
  -- desired range (typically selected in visual line mode) with render '{file}',
  -- which is automatically created with your content. In a model or controller, a
  -- concern is created, with the appropriate include declaration left behind.
  -- :help rails-:Extract
  "tpope/vim-rails",

  -- Minimal rbenv support
  "tpope/vim-rbenv",

  -- Better rspec syntax highlighting for Vim
  "keith/rspec.vim",

  -- Ruby syntax highlighting
  "vim-ruby/vim-ruby",

  -- Lightweight support for Ruby's Bundler
  "tpope/vim-bundler",

  -- Vim highlighting & completion for MiniTest
  "sunaku/vim-ruby-minitest",

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
  "tpope/vim-endwise",

  -- quoting/parenthesizing made simple
  -- "tpope/vim-surround",

  -- Provides additional text objects
  -- Example:
  -- ci* - change inside star
  -- va| - visually select around pipe
  -- ci_ - change inside underscore
  -- ca/aa/Ia/Aa  - change inside function/method argument
  -- "wellle/targets.vim",

  -- Run various tests from vim
  "janko-m/vim-test",

  -- Allows vim to communicate and run commands in tmux
  "benmills/vimux",

  -- CSS3 syntax support
  "hail2u/vim-css3-syntax",

  -- Git integration
  "tpope/vim-fugitive",
  "sindrets/diffview.nvim",

  -- Make terminal vim and tmux work better together.
  "tmux-plugins/vim-tmux-focus-events",

  -- Provides insert mode auto-completion for quotes, parens, brackets
  -- TODO: Replace of NEOVIM equvivalent
  -- "Raimondi/delimitMate",

  -- Crystal syntax support
  "vim-crystal/vim-crystal",

  -- Improved JavaScript syntax
  "pangloss/vim-javascript",

  -- JSX syntax support
  -- "mxw/vim-jsx",

  -- Multiple cursors
  "mg979/vim-visual-multi",

  -- Brewfile syntax highlighting
  "bfontaine/brewfile.vim",

  -- Auto close (X)HTML tags
  -- "alvan/vim-closetag",

  -- Base16 color schemes
  -- "Mofiqul/dracula.nvim",
  -- "folke/tokyonight.nvim",
  -- "rose-pine/neovim",
  -- "EdenEast/nightfox.nvim",
  "catppuccin/nvim",
  -- "tinted-theming/base16-vim",
  "ellisonleao/gruvbox.nvim",
  -- "rebelot/kanagawa.nvim",
  -- "dracula/vim",
  -- "sainnhe/sonokai",

  -- Delete entries from quickfix
  -- "stefandtw/quickfix-reflector.vim",

  -- Delete entries from quickfix (alt)
  "itchyny/vim-qfedit",

  -- Shows yaml path under cursor,
  -- allows to search by YAML key
  "Einenlum/yaml-revealer",

  {
    "nvim-treesitter/nvim-treesitter"
  },

  -- {
  --   "nvim-treesitter/nvim-treesitter-context"
  -- },

  {
    "chrisgrieser/nvim-spider"
  },

  -- Better yaml
  "cuducos/yaml.nvim",

  -- Better yaml folding
  -- "pedrohdz/vim-yaml-folds",

  -- Portable package manager for Neovim that runs everywhere Neovim runs.
  -- easily install and manage LSP servers, DAP servers, linters, and
  -- formatters.
  "williamboman/mason.nvim",
  -- mason-lspconfig bridges mason.nvim with the lspconfig plugin - making it
  -- easier to use both plugins together.
  "williamboman/mason-lspconfig.nvim",

  -- Configs for the Nvim LSP client (:help lsp).(Quickstart configs for Nvim LSP )
  "neovim/nvim-lspconfig",

  -- A neovim plugin that preview code with LSP code actions applied.
  -- The following backends are available:
  "aznhe21/actions-preview.nvim",
  "hrsh7th/cmp-nvim-lsp",
  "hrsh7th/cmp-buffer",
  "hrsh7th/cmp-path",
  "hrsh7th/cmp-cmdline",
  "onsails/lspkind.nvim",
  -- {
  --   "tzachar/cmp-fuzzy-buffer",
  --   dependencies = {
  --     "tzachar/fuzzy.nvim"
  --   }
  -- },

  -- Autocomplte plugin
  "hrsh7th/nvim-cmp",
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


  -- Automatically highlighting other uses of the current word under the cursor
  -- "RRethy/vim-illuminate",
  -- Alternative to vim-illuminate
  -- "tzachar/local-highlight.nvim",

  -- Utility functions for getting diagnostic status and progress messages from
  -- LSP servers, for use in the Neovim statusline
  "nvim-lua/lsp-status.nvim",
  -- Statusline
  "nvim-lualine/lualine.nvim",
  -- Alternative statusline
  -- "rebelot/heirline.nvim",

  -- Highligh color codes
  -- "lilydjwg/colorizer", -- Old plugin, works OK
  'brenoprata10/nvim-highlight-colors',
  -- "NvChad/nvim-colorizer.lua",
  -- A high-performance color highlighter for Neovim which has no
  -- external dependencies! Written in performant Luajit.
  -- "norcalli/nvim-colorizer.lua",

  -- AppArmor syntax highlight
  -- 'ClockworkNet/vim-apparmor')

  -- Improved nginx vim plugin (incl. syntax highlighting)
  -- "chr4/nginx.vim",

  -- JSON highlight
  -- "elzr/vim-json",

  -- Syntax highlighting and filetype detection for systemd unit files
  "wgwoods/vim-systemd-syntax",

  -- Auto close quotes, parenthesiz, etc
  "windwp/nvim-autopairs",
  -- Use treesitter to autoclose and autorename html tag
  -- "windwp/nvim-ts-autotag",

  "andymass/vim-matchup",
  -- Alternative plugin
  -- "echasnovski/mini.pairs",

  --- Syntax highlighting for Nix configs
  -- "LnL7/vim-nix",

  -- Dracula color scheme
  -- 'dracula/vim',

  -- Better markdown support
  -- "plasticboy/vim-markdown",

  -- unimpaired.vim: Pairs of handy bracket mappings
  "tpope/vim-unimpaired",

  -- GTK Blueprint syntax
  -- "thetek42/vim-blueprint-syntax",

  -- Switch between multiline and signleline code
  "AndrewRadev/splitjoin.vim",

  -- Treesitter-aware split/join (smarter than splitjoin.vim)
  { "Wansmer/treesj", dependencies = { "nvim-treesitter/nvim-treesitter" } },

  -- Switch between different things
  -- 'AndrewRadev/switch.vim',

  -- Highlight matching HTML tag
  -- TODO: check how good is performance
  -- 'leafOfTree/vim-matchtag',

  -- Global search by ack cli util
  -- "mileszs/ack.vim",

  -- Emmet
  {
    "mattn/emmet-vim",
    -- TODO: write issue on github regarding bug on main
    commit = "3fb2f63799e1922f7647ed9ff3b32154031a76ee"
  },
  -- LSP for emmet
  -- "olrtg/nvim-emmet",

  -- Indent line guides
  -- "lukas-reineke/indent-blankline.nvim",

  -- Easily navigate between vim and tmux panes
  "christoomey/vim-tmux-navigator",

  "ray-x/navigator.lua",

  -- Old and broken
  -- Snippets
  -- "MarcWeber/vim-addon-mw-utils",
  "L3MON4D3/LuaSnip",
  'saadparwaiz1/cmp_luasnip',
  -- "rafamadriz/friendly-snippets",

  -- Tabline
  "akinsho/bufferline.nvim",

  -- Show scrollbar for VIM buffer(SUPER COOL!)
   'petertriho/nvim-scrollbar',
   "kevinhwang91/nvim-hlslens",
   "lewis6991/gitsigns.nvim",

  -- Run linters and formaters as fake LSP
  -- 'jose-elias-alvarez/null-ls.nvim',
  -- Linting syntastic like plugin
  'mfussenegger/nvim-lint',

  -- Use local Ollama AI in VIM
  "David-Kunz/gen.nvim",

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

  -- Formating framework (like null-ls, syntastic, etc)
  "stevearc/conform.nvim",

  -- Measure startuptime
  "dstein64/vim-startuptime",

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

  -- Show methods in file in sidebar(Has nice navigaton)
  "stevearc/aerial.nvim",

  -- Use both plugins for outline
  -- Show methods in file in sidebar (Has nice highlight)
  {
    'hedyhli/outline.nvim',
    event = "VeryLazy",
    dependencies = {
      'epheien/outline-treesitter-provider.nvim'
    }
  },

  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      -- your configuration comes here
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
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


  -- "ggandor/leap.nvim",

  {
    "folke/flash.nvim",
    event = "VeryLazy",
    ---@type Flash.Config
    opts = {},
    -- stylua: ignore
  },

  {
    "OXY2DEV/markview.nvim",
    lazy = false,
    dependencies = { "nvim-tree/nvim-web-devicons" },
  },

  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    ft = { "markdown" },
    build = function() vim.fn["mkdp#util#install"]() end,
  },

  "folke/snacks.nvim",
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

  -- "weizheheng/ror.nvim",
  -- "jonsmithers/vim-html-template-literals",

  -- Very cool search & replace plugin similar to Atom
  -- "MagicDuck/grug-far.nvim",

  -- A collection of improvements for the quickfix buffer
  -- "stevearc/qf_helper.nvim",
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
  -- ======== Tesing area ====================
  -- "rcarriga/nvim-notify",
  -- "stevearc/dressing.nvim",

  -- ============= CURRENT EXPERIMENTAL PLUGINS ======================

  -- VSCode bulb bulb for neovim's built-in LSP.
  -- 'kosayoda/nvim-lightbulb',

  -- A lightweight LSP plugin based on Neovim's built-in LSP with a highly
  -- performant UI.
  -- 'glepnir/lspsaga.nvim',

  -- A plugin to visualise and resolve merge conflicts in neovim
  -- 'akinsho/git-conflict.nvim',
  -- 'rhysd/conflict-marker.vim',
  -- 'folke/neodev.nvim',

  -- A pretty list for showing diagnostics, references, telescope results,
  -- quickfix and location lists to help you solve all the trouble your code is
  -- causing.
  --
  -- 'MunifTanjim/prettier.nvim',

  ----------------- NEXT IN LINE ========================
  -- "folke/trouble.nvim",

  -- Neovim setup for init.lua and plugin development with full signature help,
  -- docs and completion for the nvim lua API.
  -- 'folke/neodev.nvim',
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
