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
  -- Filetree
  -- "scrooloose/nerdtree",
  -- TODO: Replace nerdtree with fern
  -- "lambdalisue/fern.vim",

  -- Provides devicons
  -- Requires nerdfont: (https://www.nerdfonts.com/)
  "nvim-tree/nvim-web-devicons",

  -- Nerdtree like file exploer
  -- 'nvim-tree/nvim-tree.lua',

  {
  "nvim-neo-tree/neo-tree.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    }
  },

  -- Comment helper
  "tomtom/tcomment_vim",

  -- Enable in future
  "nvim-treesitter/nvim-treesitter",

  -- Linting
  -- "w0rp/ale",

  -- TODO Alternative linting plugin(Consider to switch in future)
  -- "neomake/neomake",

  -- Enable repeating supported plugin maps with '.'
  "tpope/vim-repeat",

  -- FZF integration
  -- "junegunn/fzf.vim",
  {
    'nvim-telescope/telescope.nvim', tag = '0.1.1',
    dependencies = { 'nvim-lua/plenary.nvim' }
  },

  -- Show changed lines from git
  "airblade/vim-gitgutter",

  -- Lightweight support for Ruby's Bundler
  "tpope/vim-bundler",

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
  "wellle/targets.vim",

  -- Run various tests from vim
  "janko-m/vim-test",

  -- Easily navigate between vim and tmux panes
  "christoomey/vim-tmux-navigator",

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
  "rhysd/vim-crystal",

  -- Improved JavaScript syntax
  "pangloss/vim-javascript",

  -- JSX syntax support
  "mxw/vim-jsx",

  -- Multiple cursors
  "mg979/vim-visual-multi",

  -- Brewfile syntax highlighting
  "bfontaine/brewfile.vim",

  -- Auto close (X)HTML tags
  "alvan/vim-closetag",

  -- Emmet
  "mattn/emmet-vim",

  -- Base16 color schemes
  "tinted-theming/base16-vim",
  -- "RRethy/nvim-base16",
  -- TODO: replace with:
  -- (https://github.com/RRethy/nvim-base16)
  -- OR with (https://github.com/tinted-theming/base16-vim)

 -- Shows yaml path under cursor,
 -- allows to search by YAML key
 "Einenlum/yaml-revealer",

 -- Better yaml folding
 "pedrohdz/vim-yaml-folds",

  -- Snippets
  -- "MarcWeber/vim-addon-mw-utils",
  -- "L3MON4D3/LuaSnip",
  'dcampos/nvim-snippy',
  -- addition for nvim-cmp
  -- 'dcampos/cmp-snippy'


  -- Automatically highlighting other uses of the current word under the cursor
  "RRethy/vim-illuminate",

  -- Lighline base16 themes
  -- TODO: replace with NEOVIM equvivalent
  -- "nolo18/base16lightline",
  -- -- Statusline
  -- "itchyny/lightline.vim",
  -- -- Base16 colors for lightline
  -- "daviesjamie/vim-base16-lightline",
  -- -- Show ale errors in lightline
  -- "maximbaz/lightline-ale",


  -- Statusline plugin
  "nvim-lualine/lualine.nvim",
  -- Alternative statusline
  -- "rebelot/heirline.nvim",


  -- Highligh color codes
  "lilydjwg/colorizer",

  -- AppArmor syntax highlight
  -- 'ClockworkNet/vim-apparmor')

  -- Improved nginx vim plugin (incl. syntax highlighting)
  "chr4/nginx.vim",

  -- JSON highlight
  "elzr/vim-json",

  -- Syntax highlighting and filetype detection for systemd unit files
  "wgwoods/vim-systemd-syntax",

  --- Syntax highlighting for Nix configs
  -- "LnL7/vim-nix",

  -- Dracula color scheme
  -- 'dracula/vim',

  -- Better markdown support
  "plasticboy/vim-markdown",

  -- unimpaired.vim: Pairs of handy bracket mappings
  "tpope/vim-unimpaired",

  -- GTK Blueprint syntax
  "thetek42/vim-blueprint-syntax",

  -- Switch between multiline and signleline code
  "AndrewRadev/splitjoin.vim",

  -- Switch between different things
  -- 'AndrewRadev/switch.vim',

  -- Line indentation
  -- "Yggdroot/indentLine", { 'for': ['html', 'eruby'] }

  -- Highlight matching HTML tag
  "leafOfTree/vim-matchtag",

  -- Global search by ack cli util
  "mileszs/ack.vim"
})
