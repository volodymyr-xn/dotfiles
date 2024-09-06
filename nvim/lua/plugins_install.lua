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
  -- TODO: Replace nerdtree with fern
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

  "ibhagwan/fzf-lua",

  -- Comment helper
  -- "tomtom/tcomment_vim",
  -- Alternative plugin:
  -- "preservim/nerdcommenter",
  "numToStr/Comment.nvim",

  "tpope/vim-haml",

  -- Linting
  -- "w0rp/ale",

  -- TODO Alternative linting plugin(Consider to switch in future)
  -- "neomake/neomake",

  -- Enable repeating supported plugin maps with '.'
  "tpope/vim-repeat",

  'alvan/vim-closetag',

  -- FZF integration
  {
    "junegunn/fzf.vim",
    dependencies = { 'junegunn/fzf' }
  },

  -- Lua port of FZF for neovim
  -- (https://github.com/ibhagwan/fzf-lua)

  {
    'nvim-telescope/telescope.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' }
  },
  "nvim-telescope/telescope-ui-select.nvim",
  -- Enabled live grep in dir
  "nvim-telescope/telescope-live-grep-args.nvim",

  {
    'nvim-telescope/telescope-fzf-native.nvim',
    -- build = 'make'
    build = 'cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release && cmake --install build --prefix build'
  },
  -- An extension for telescope.nvim that allows you to import modules faster
  -- based on what you've already imported in your project.
  -- "piersolenski/telescope-import.nvim",
  'piersolenski/telescope-import.nvim',

  -- Show changed lines from git
  "airblade/vim-gitgutter",
  -- TODO: Consider switch to
  -- 'lewis6991/gitsigns.nvim',

  -- Lightweight support for Ruby's Bundler
  -- "tpope/vim-bundler",

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

  -- Vim highlighting & completion for MiniTest
  "sunaku/vim-ruby-minitest",

  -- Create your own text objects
  "kana/vim-textobj-user",

  -- Make text objects with various ruby block structures.
  -- TODO: replace with NEOVIM equvivalent
  -- "rhysd/vim-textobj-ruby",

  -- Automaticaly add end in ruby scrips
  "tpope/vim-endwise",

  -- quoting/parenthesizing made simple
  "tpope/vim-surround",

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

  -- Make terminal vim and tmux work better together.
  "tmux-plugins/vim-tmux-focus-events",

  -- Provides insert mode auto-completion for quotes, parens, brackets
  -- TODO: Replace of NEOVIM equvivalent
  -- "Raimondi/delimitMate",

  -- Crystal syntax support
  -- "rhysd/vim-crystal",

  -- Improved JavaScript syntax
  "pangloss/vim-javascript",

  -- JSX syntax support
  -- "mxw/vim-jsx",

  -- Multiple cursors
  "mg979/vim-visual-multi",

  -- Brewfile syntax highlighting
  "bfontaine/brewfile.vim",

  -- Auto close (X)HTML tags
  "alvan/vim-closetag",

  -- Use treesitter to autoclose and autorename html tag
  -- https://github.com/windwp/nvim-ts-autotag
  -- "windwp/nvim-ts-autotag",

  -- Base16 color schemes
  -- "Mofiqul/dracula.nvim",
  -- "folke/tokyonight.nvim",
  "rose-pine/neovim",
  -- "EdenEast/nightfox.nvim",
  "catppuccin/nvim",
  "tinted-theming/base16-vim",
  "ellisonleao/gruvbox.nvim",
  "rebelot/kanagawa.nvim",
  "dracula/vim",
  "sainnhe/sonokai",

  -- Shows yaml path under cursor,
  -- allows to search by YAML key
  "Einenlum/yaml-revealer",

  "nvim-treesitter/nvim-treesitter",

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

  -- A neovim plugin that preview code with LSP code actions applied.
  -- The following backends are available:
  "aznhe21/actions-preview.nvim",

  -- Configs for the Nvim LSP client (:help lsp).(Quickstart configs for Nvim LSP )
  "neovim/nvim-lspconfig",
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
  "hrsh7th/nvim-cmp",
  -- "lukas-reineke/cmp-rg",

  -- 'zbirenbaum/copilot.lua',
  -- "zbirenbaum/copilot-cmp",
  -- "ray-x/cmp-treesitter",


  -- Automatically highlighting other uses of the current word under the cursor
  "RRethy/vim-illuminate",
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

  -- Switch between different things
  -- 'AndrewRadev/switch.vim',

  -- Line indentation
  -- "Yggdroot/indentLine", { 'for': ['html', 'eruby'] }

  -- Highlight matching HTML tag
  -- "leafOfTree/vim-matchtag",

  -- Global search by ack cli util
  -- "mileszs/ack.vim",

  -- Emmet
  {
    "mattn/emmet-vim",
    commit = "3fb2f63799e1922f7647ed9ff3b32154031a76ee"
  },
  "olrtg/nvim-emmet",

  -- Indent line guides
  -- "lukas-reineke/indent-blankline.nvim",

  -- Easily navigate between vim and tmux panes
  "christoomey/vim-tmux-navigator",

  "ray-x/navigator.lua",

  -- Old broken
  -- 'dcampos/nvim-snippy',
  -- addition for nvim-cmp
  -- 'dcampos/cmp-snippy',
  -- Snippets
  -- "MarcWeber/vim-addon-mw-utils",
  "L3MON4D3/LuaSnip",
  'saadparwaiz1/cmp_luasnip',
  -- "rafamadriz/friendly-snippets",

  -- Tabline
  "akinsho/bufferline.nvim",

  -- Show scrollbar for VIM buffer(SUPER COOL!)
  -- 'dstein64/nvim-scrollview',
   'petertriho/nvim-scrollbar',

  -- Run linters and formaters as fake LSP
  -- 'jose-elias-alvarez/null-ls.nvim',
  -- Linting syntastic like plugin
  'mfussenegger/nvim-lint',

  -- Use local Ollama AI in VIM
  "David-Kunz/gen.nvim",

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

  -- A collection of improvements for the quickfix buffer
  -- "stevearc/qf_helper.nvim",

  {
    "ray-x/go.nvim",
    dependencies = {  -- optional packages
      "ray-x/guihua.lua",
      "neovim/nvim-lspconfig",
      "nvim-treesitter/nvim-treesitter",
    },
    config = function()
      require("go").setup()
    end,
    event = {"CmdlineEnter"},
    ft = {"go", 'gomod'},
    build = ':lua require("go.install").update_all_sync()' -- if you need to install/update all binaries
  }

  -- "rcarriga/nvim-notify",
  -- "stevearc/dressing.nvim",
  -- "weizheheng/ror.nvim",

  -- "jonsmithers/vim-html-template-literals",

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
  -- Use treesitter to auto close and auto rename html tag
  -- windwp/nvim-ts-autotag
  -- kevinhwang91/nvim-hlslens
  -- kevinhwang91/nvim-ufo
  --
  -- Easy navigation like EasyMotion.vim
  -- 'phaazon/hop.nvim/'
  -- folke/noice.nvim
  -- 'm-demare/hlargs.nvim'
})
