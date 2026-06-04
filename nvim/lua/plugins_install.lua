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

-- lazy.nvim options. MUST be passed as the second argument to lazy.setup()
-- — the single-argument form `lazy.setup({mixed})` treats the whole table as
-- a plugin spec, so any sibling `performance = {...}` keys are SILENTLY
-- IGNORED. We hit that footgun in this config: `disabled_plugins` looked
-- active for years but never disabled anything, and `cache.enabled = false`
-- got dropped on the floor, letting `vim.loader` keep serving stale
-- bytecode (the root cause of the recurring git_diff_popup bug).
local lazy_opts = {
  performance = {
    -- Disable lazy's bytecode cache (which is `vim.loader` under the hood).
    -- See the long-form rationale in init.lua. Without this, lazy re-enables
    -- `vim.loader` automatically, undoing our deliberate skip in init.lua.
    cache = { enabled = false },
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
}

require("lazy").setup({
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
    -- README pins `v3.x` so a future v4 release doesn't roll over silently.
    branch = "v3.x",
    cmd = { "Neotree" },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
    },
    config = function() require("plugin_settings.neo_tree") end,
  },

  -- Easily navigate between vim and tmux panes. Eager on purpose: the
  -- plugin installs `<C-h/j/k/l/\>` defaults on load, and the user's
  -- `<C-\>` → Neotree-toggle binding in `keymappings/files.lua` then
  -- overrides the `<C-\>` default (load order: plugins_install runs at
  -- init.lua:18, keymappings.files at init.lua:34). Lazy-loading breaks
  -- this because the plugin's defaults arrive *after* the override.
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

  -- All four pickers below are reached only through
  -- `my_plugins.fuzzy_picker_selector` (which `require`s the chosen one) or
  -- through their own `:` commands. `lazy = true` defers them until that
  -- require fires; `cmd` covers direct command invocation.
  {
    "dmtrKovalenko/fff.nvim",
    lazy = true,
    -- Without `opts`/`config`, fff's `setup()` never runs and any
    -- non-default option is ignored.
    opts = {},
    build = ':lua require("fff.download").download_or_build_binary()',
  },

  { "ibhagwan/fzf-lua", lazy = true, cmd = "FzfLua" },

  -- FZF integration. Eager on purpose: the custom commands defined in
  -- `custom_file_selectors/fzf_vim.lua` (CustomFullTextSearch,
  -- CustomFullTextSearchRg, FZFLines, SearchChangedFilesFZF, …) call
  -- `fzf#run()` / `fzf#vim#grep()` vimscript functions which lazy.nvim
  -- can't intercept, so fzf.vim must be loaded when those commands fire.
  {
    "junegunn/fzf.vim",
    dependencies = { 'junegunn/fzf' },
    config = function() require("plugin_settings.fzf") end,
  },

  -- Telescope is the default picker and is also reached through
  -- `fuzzy_picker_selector`. `cmd = "Telescope"` handles direct invocation;
  -- lazy.nvim additionally loads it on first `require("telescope")`. Its
  -- three extensions are now declared as dependencies so they no longer
  -- sit at top level eager.
  {
    'nvim-telescope/telescope.nvim',
    cmd = "Telescope",
    -- Previous commit pin `cb3f98d...` (Sep 2024) was removed: no comment
    -- documented what it pinned around, and 8 months of upstream fixes
    -- (grep_string pipe-escape, vim.F deprecation stub, etc.) were
    -- inaccessible. If a regression on master recurs, re-pin WITH a
    -- comment naming the specific bug.
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-telescope/telescope-ui-select.nvim',
      'nvim-telescope/telescope-live-grep-args.nvim',
      {
        'nvim-telescope/telescope-fzf-native.nvim',
        -- Upstream bumped its own cmake_minimum_required to 3.5 in
        -- PR #158, so the previous `-DCMAKE_POLICY_VERSION_MINIMUM=3.5`
        -- workaround is no longer needed.
        build = 'cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release --target install',
      },
    },
    config = function() require("plugin_settings.telescope") end,
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
    cmd = { "G", "Git", "Gdiffsplit", "Gvdiffsplit", "Gread", "Gwrite", "Ggrep", "Glgrep", "Gclog", "Gllog", "Gedit", "Gsplit", "Gvsplit", "Gtabedit", "Gpedit", "GBrowse", "Gmove", "Grename", "Gdelete", "Gremove" },
    config = function() require("plugin_settings.fugitive") end,
  },
  -- {
  --   "sindrets/diffview.nvim",
  --   cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewToggleFiles", "DiffviewFocusFiles", "DiffviewFileHistory", "DiffviewRefresh" },
  --   config = function() require("plugin_settings.diffview") end,
  -- },
  {
    "lewis6991/gitsigns.nvim",
    -- Include BufWritePost so signs attach when you `:w` a new file
    -- into a git tree (the .git entry only appears after the write).
    event = { "BufReadPre", "BufNewFile", "BufWritePost" },
    config = function() require("plugin_settings.gitsigns") end,
  },

  -- A plugin to visualise and resolve merge conflicts in neovim
  -- 'akinsho/git-conflict.nvim',
  -- 'rhysd/conflict-marker.vim',

  -- ============================================================
  -- LSP & completion
  -- ============================================================

  -- Mason is loaded as a dependency of nvim-lspconfig (declared below);
  -- no top-level entry. Per mason's README: "Lazy-loading the plugin, or
  -- somehow deferring the setup, is not recommended." The lspconfig dep
  -- arrangement loads mason eagerly with lspconfig on BufReadPre, which
  -- is the closest acceptable approximation.
  -- mason-lspconfig bridges mason.nvim with the lspconfig plugin. Also a
  -- dependency of nvim-lspconfig (declared below) and loads with it; no
  -- top-level entry needed.

  -- Configs for the Nvim LSP client (:help lsp).(Quickstart configs for Nvim LSP )
  -- Lazy on first real buffer; mason + mason-lspconfig load as deps right
  -- before lsp_config runs, so mason.setup()/mason-lspconfig.setup() no
  -- longer cost anything at startup.
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    -- Org moved from `williamboman` to `mason-org` (the old URLs 301-redirect
    -- today but every current README/issue points to mason-org).
    dependencies = { "mason-org/mason.nvim", "mason-org/mason-lspconfig.nvim" },
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

  -- Autocomplete plugin. Completion is only needed in insert mode and the
  -- `:` cmdline, so `InsertEnter` + `CmdlineEnter` cover every entry point
  -- without delaying the first popup. LuaSnip and its cmp source are now
  -- declared as deps so they defer together.
  {
    "hrsh7th/nvim-cmp",
    event = { "InsertEnter", "CmdlineEnter" },
    dependencies = {
      "aznhe21/actions-preview.nvim",
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-cmdline",
      "onsails/lspkind.nvim",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
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

  -- Code navigation via LSP. No callsites currently in this repo, so it
  -- only loads if the user invokes its commands directly. `lazy = true`
  -- means lazy.nvim won't pull it in until `require("navigator")` runs.
  { "ray-x/navigator.lua", lazy = true },

  -- LuaSnip + cmp source live as deps of nvim-cmp above (load on
  -- InsertEnter). Keep the config here so plugin_settings/luasnip.lua
  -- still runs when LuaSnip is loaded.
  {
    "L3MON4D3/LuaSnip",
    lazy = true,
    config = function() require("plugin_settings.luasnip") end,
  },
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

  -- Treesitter-aware commentstring. Only matters when commenting inside a
  -- real buffer; defer until one is open. `init` sets the skip-flag
  -- before nvim-treesitter loads to silence the deprecated-module warning
  -- and avoid double-registration; `config` runs the new setup() entry
  -- (the old `require("nvim-treesitter.configs").setup{ context_commentstring = ... }`
  -- module path is deprecated). See JoosepAlviste/nvim-ts-context-commentstring#91.
  {
    "JoosepAlviste/nvim-ts-context-commentstring",
    event = { "BufReadPre", "BufNewFile" },
    init = function() vim.g.skip_ts_context_commentstring_module = true end,
    config = function() require("ts_context_commentstring").setup({}) end,
  },

  {
    "nvim-treesitter/nvim-treesitter",
    -- Pin to the legacy `master` branch. Upstream was archived 2026-04-03
    -- and the new `main` branch is an incompatible rewrite (no
    -- `require("nvim-treesitter.configs").setup{}` API). `version = false`
    -- tells lazy to ignore tags and track the branch head.
    branch = "master",
    version = false,
    dependencies = {
      -- Ships the `queries/<lang>/textobjects.scm` files (incl. ruby's
      -- @function.outer/@function.inner mapped to `method` /
      -- `singleton_method`, and @class.outer/@class.inner mapped to
      -- `class` / `module`). mini.ai's gen_spec.treesitter reads these
      -- queries to power af/if/ac/ic. The plugin's own keymap module is
      -- intentionally NOT configured — mini.ai owns the mappings.
      { "nvim-treesitter/nvim-treesitter-textobjects", branch = "master" },
    },
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

  -- (removed `tpope/vim-haml` — nvim ships haml ftplugin/syntax/indent
  -- vendored from this same upstream. Re-add and scope to `ft = { "haml",
  -- "sass", "scss" }` only if you need a newer upstream Sass parser.)

  -- Ruby on Rails power tool
  -- This is a massive (in a good way) Vim plugin for editing Ruby on Rails applications.
  -- Partial and concern extraction. In a view, :Extract {file} replaces the
  -- desired range (typically selected in visual line mode) with render '{file}',
  -- which is automatically created with your content. In a model or controller, a
  -- concern is created, with the appropriate include declaration left behind.
  -- :help rails-:Extract
  {
    "tpope/vim-rails",
    -- `yaml` was dead config: vim-rails ships only ftplugin/railslog.vim
    -- and detects Rails via autoload on ruby/eruby/haml buffers.
    ft = { "ruby", "eruby", "haml" },
    config = function() require("plugin_settings.vim_rails") end,
  },

  -- Better rspec syntax highlighting for Vim
  { "keith/rspec.vim", ft = "ruby" },

  -- (removed `vim-ruby/vim-ruby` — nvim's runtime already vendors it:
  -- runtime/ftplugin/ruby.vim, syntax/ruby.vim, indent/ruby.vim are all
  -- credited to vim-ruby. Installing it again loaded the same code twice
  -- per ruby buffer.)

  -- Vim highlighting & completion for MiniTest
  { "sunaku/vim-ruby-minitest", ft = "ruby" },

  -- "weizheheng/ror.nvim",
  -- "jonsmithers/vim-html-template-literals",

  -- CSS3 syntax support. `scss` was dead config: plugin only extends
  -- syntax/css.vim and ships no after/syntax/scss.vim.
  { "hail2u/vim-css3-syntax", ft = "css" },

  -- Crystal syntax support
  { "vim-crystal/vim-crystal", ft = "crystal" },

  -- Improved JavaScript syntax. `javascriptreact` was dead — the plugin's
  -- ftdetect only sets `filetype=javascript`. (Note: nvim's built-in
  -- ftplugin/syntax + treesitter already cover JS; consider removing
  -- this entry entirely if you don't rely on its specific overrides.)
  { "pangloss/vim-javascript", ft = "javascript" },

  -- JSX syntax support
  -- "mxw/vim-jsx",

  -- Brewfile syntax highlighting
  -- { "bfontaine/brewfile.vim", ft = "ruby" },

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

  -- (removed `wgwoods/vim-systemd-syntax` — nvim 0.10+ ships
  -- ftplugin/systemd.vim, syntax/systemd.vim, and ~40 systemd filename
  -- patterns in filetype.lua. Upstream is also unmaintained since 2011.)

  --- Syntax highlighting for Nix configs
  -- "LnL7/vim-nix",

  -- Better markdown support
  -- "plasticboy/vim-markdown",

  -- GTK Blueprint syntax
  -- "thetek42/vim-blueprint-syntax",

  -- Emmet. The previous commit pin (2024 AVIF-support commit) was
  -- removed — upstream master since gained a shellescape command-injection
  -- fix, parseIntoTree/mergeConfig bug fixes, and treesitter deprecation
  -- handling. If the "bug on main" mentioned in the old TODO recurs, pin
  -- to the specific known-good commit again WITH a comment explaining
  -- what bug it pins around.
  {
    "mattn/emmet-vim",
    ft = { "html", "css", "scss", "sass", "javascriptreact", "typescriptreact", "vue", "eruby", "haml", "xml" },
    config = function() require("plugin_settings.emmet") end,
  },
  -- LSP for emmet
  -- "olrtg/nvim-emmet",

  -- {
  --   "OXY2DEV/markview.nvim",
  --   ft = { "markdown", "Avante", "codecompanion" },
  --   dependencies = { "nvim-tree/nvim-web-devicons" },
  --   config = function() require("plugin_settings.markview") end,
  -- },

  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    -- Include `markdown.mdx` so `.mdx` files trigger the ft load.
    -- `g:mkdp_filetypes` must be set BEFORE the plugin loads (it's read
    -- once at plugin init), hence `init`, not `config`.
    ft = { "markdown", "markdown.mdx" },
    init = function()
      vim.g.mkdp_filetypes = { "markdown", "markdown.mdx" }
    end,
    -- Force-load the plugin before running its build hook so the
    -- `mkdp#util#install` vim function is on rtp. Bare
    -- `vim.fn["mkdp#util#install"]()` errors on fresh install
    -- because lazy hasn't added the plugin source yet.
    -- See iamcco/markdown-preview.nvim#690.
    build = function()
      require("lazy").load({ plugins = { "markdown-preview.nvim" } })
      vim.fn["mkdp#util#install"]()
    end,
  },

  -- ============================================================
  -- Editing (motions, textobjs, pairs, surround, comments)
  -- ============================================================

  -- Core text-object engine. Defaults give a/i variants for brackets,
  -- quotes, args, plus next/last (`an`/`in`, `al`/`il`). `f`/`c` are
  -- overridden in plugin_settings/mini_ai.lua to use treesitter queries.
  -- Examples (c = change, d = delete, v = visual-select; swap freely):
  --   cif / daf       - inner / around function body (def...end)
  --   cic / dac       - inner / around class/module body
  --   ci( ci[ ci{ ci< - inside specific bracket pair
  --   ca( da{         - around specific bracket pair
  --   cib / dab       - inside / around any bracket (b = brace-ish)
  --   ci' ci" ci`     - inside specific quote
  --   ciq             - inside any quote
  --   ci, ca,         - inside / around function argument
  --   ci? - then "x" <CR> "y" <CR> - inside user-prompted x..y range
  --   cin( / cal{     - next paren / around last brace
  {
    "echasnovski/mini.ai",
    version = "*",
    config = function() require("plugin_settings.mini_ai") end,
  },

  -- Alternative plugin:
  -- "preservim/nerdcommenter",
  -- At the time of installing (2024) only tpope/vim-commentary
  -- works correcly for commenting erb files. `gc`/`gcc` are the only
  -- triggers; lazy.nvim loads the plugin when one fires.
  {
    "tpope/vim-commentary",
    keys = {
      { "gc", mode = { "n", "x", "o" } },
      { "gcc", mode = "n" },
    },
  },

  -- Enable repeating supported plugin maps with '.'. Hooks `.` only after
  -- another plugin map fires, so post-startup is fine.
  -- { "tpope/vim-repeat", event = "VeryLazy" },

  -- 'alvan/vim-closetag',

  -- Create your own text objects. Framework lib — only matters when a
  -- consumer plugin defines a textobj; safe to defer past startup.
  { "kana/vim-textobj-user", event = "VeryLazy" },

  -- Make text objects with various ruby block structures.
  -- TODO: replace with NEOVIM equvivalent
  -- "rhysd/vim-textobj-ruby",
  -- {
  --   "chrisgrieser/nvim-various-textobjs",
  --   event = "VeryLazy",
  --   opts = {
  --     keymaps = {
  --       useDefaults = true
  --     }
  --   }
  -- },

  -- Indent-scoped text objects. Useful for YAML, Python, deeply-nested
  -- blocks, and HAML/Slim where braces don't exist.
  -- Examples:
  --   vii / dii / cii - inner indent level (lines at >= current indent)
  --   vai / dai / cai - same + one line above (block "header")
  --   viI / vaI       - same + line below (full block incl. footer)
  --   >ii / <ii       - shift indent block right / left
  {
    "michaeljsmith/vim-indent-object",
    keys = {
      { "ai", mode = { "x", "o" } },
      { "ii", mode = { "x", "o" } },
      { "aI", mode = { "x", "o" } },
      { "iI", mode = { "x", "o" } },
    },
  },

  -- Automaticaly add end in ruby scrips
  {
    "tpope/vim-endwise",
    ft = { "ruby", "lua", "vim", "sh", "zsh", "elixir", "crystal"
    }
  },

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

  -- Multiple cursors. Defaults bind many leader-prefixed keys (\\a, \\\\,
  -- etc.) so enumerating them in `keys` is brittle — deferring past
  -- startup via VeryLazy is the safe trade-off.
  { "mg979/vim-visual-multi", event = "VeryLazy" },

  -- Auto close quotes, parenthesis, etc
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = function() require("plugin_settings.nvim_autopairs") end,
  },

  -- Extends `%` to match `def`/`end`, `if`/`end`, `do`/`end`, html tags,
  -- erb/haml blocks, etc. Also adds `i%`/`a%` text objects spanning the
  -- whole matched construct.
  -- Examples:
  --   %               - jump to matching open/close keyword
  --   g%              - jump to previous match
  --   [% / ]%         - jump to outer open / close of current block
  --   ci% / da%       - inner / around matched block (def...end body)
  --   vi% / va%       - visual-select inner / around matched block
  --   z%              - jump inside next/previous nested block
  --   I use this plugin to show matchin parenies
  --
  -- No `event` deferral: upstream README explicitly recommends against
  -- it ("if you run into issues, remove the event key as a first
  -- debugging step"). `g:loaded_matchit = 1` is set in
  -- general_settings.lua before `filetype plugin on`, so built-in
  -- ftplugins populate `b:match_words` on the first FileType event.
  {
    "andymass/vim-matchup",
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

  -- Subword-aware w/b/ge motions. `e` is intentionally NOT a trigger
  -- (and not remapped in plugin_settings.nvim_spider) because
  -- keymappings/navigation.lua owns `e → E` for move-to-end-of-WORD.
  {
    "chrisgrieser/nvim-spider",
    keys = {
      { "w", mode = { "n", "o", "x" } },
      { "b", mode = { "n", "o", "x" } },
      { "ge", mode = { "n", "o", "x" } },
    },
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

  -- {
  --   "folke/flash.nvim",
  --   event = "VeryLazy",
  --   config = function() require("plugin_settings.flash") end,
  -- },

  -- ============================================================
  -- UI (statusline, tabline, scrollbar, colors, highlights)
  -- ============================================================

  -- Provides devicons
  -- Requires nerdfont: (https://www.nerdfonts.com/)
  -- "nvim-tree/nvim-web-devicons",

  "echasnovski/mini.icons",
  -- mini.extra is a grab-bag helper collection; nothing on the critical
  -- path needs it at startup.
  { "echasnovski/mini.extra", version = "*", event = "VeryLazy" },

  -- Base16 color schemes
  -- "Mofiqul/dracula.nvim",
  -- "folke/tokyonight.nvim",
  -- "rose-pine/neovim",
  -- "EdenEast/nightfox.nvim",
  -- Colorscheme. `name = "catppuccin"` overrides lazy's default folder
  -- name (the repo is `catppuccin/nvim`, so without `name` it installs
  -- under `~/.local/share/nvim/lazy/nvim/`, confusing the :Lazy UI).
  -- `priority = 1000` + `lazy = false` ensures it loads before any
  -- plugin that calls `vim.cmd.colorscheme("catppuccin")` on a deferred
  -- event (lualine, bufferline) — otherwise the first paint briefly
  -- shows the default scheme before the theme kicks in.
  { "catppuccin/nvim", name = "catppuccin", priority = 1000, lazy = false },
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

  -- Statusline. `VeryLazy` (matches LazyVim default) — every component
  -- source (LSP status, git branch, filetype) initializes only after
  -- startup is otherwise complete, saving startup time.
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    config = function() require("plugin_settings.lualine") end,
  },
  -- Alternative statusline
  -- "rebelot/heirline.nvim",

  -- Highligh color codes
  -- "lilydjwg/colorizer", -- Old plugin, works OK
  -- BufReadPre per the catgoose README — fires before FileType syntax
  -- setup, so colors render on the first paint without flicker.
  {
    'catgoose/nvim-colorizer.lua',
    event = { "BufReadPre", "BufNewFile" },
    config = function() require("plugin_settings.colorizer") end,
  },
  -- Kept installed for easy fallback; never auto-loaded.
  -- Re-add event/config to reactivate (and comment catgoose above).
  {
    'brenoprata10/nvim-highlight-colors',
    lazy = true,
  },
  -- "NvChad/nvim-colorizer.lua",
  -- A high-performance color highlighter for Neovim which has no
  -- external dependencies! Written in performant Luajit.
  -- "norcalli/nvim-colorizer.lua",

  -- Tabline. Switched off VeryLazy: VeryLazy fires AFTER BufAdd events
  -- from CLI args (`nvim file1 file2`) and session restore, so the
  -- tabline missed those buffers. BufReadPost+BufNewFile loads earlier
  -- and catches every buffer. See akinsho/bufferline.nvim#899.
  {
    "akinsho/bufferline.nvim",
    event = { "BufReadPost", "BufNewFile" },
    config = function() require("plugin_settings.tabline_bufferline") end,
  },

  -- Show scrollbar for VIM buffer(SUPER COOL!)
  {
    'petertriho/nvim-scrollbar',
    event = { "BufReadPost", "BufNewFile" },
    config = function() require("plugin_settings.nvim_scrollview") end,
  },
  {
    "kevinhwang91/nvim-hlslens",
    event = { "BufReadPost", "BufNewFile" },
    dependencies = { "petertriho/nvim-scrollbar" },
    config = function() require("plugin_settings.nvim_hlslens") end,
  },

  -- Indent line guides
  -- "lukas-reineke/indent-blankline.nvim",

  -- {
  --   "folke/snacks.nvim",
  --   lazy = false,
  --   priority = 1000,
  --   opts = {},
  -- },


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

  -- Delete entries from quickfix (alt). `ft = "qf"` would load on
  -- FileType qf, which fires AFTER the plugin's `BufReadPost quickfix`
  -- autocmd — so its qfedit#new() never runs for the current buffer.
  -- `event = "QuickFixCmdPost"` loads on the same event the plugin's
  -- own autocmd listens for.
  { "itchyny/vim-qfedit", event = "QuickFixCmdPost" },

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

  -- Run various tests from vim. Vimux is the configured strategy (see
  -- plugin_settings/vim_test.lua: test#strategy = 'vimux').
  {
    "janko-m/vim-test",
    cmd = { "TestNearest", "TestFile", "TestSuite", "TestLast", "TestVisit" },
    -- `dependencies = { "benmills/vimux" }` was dead config: vimux is
    -- declared as an eager top-level entry below, so it's always loaded
    -- before vim-test's cmd fires.
    config = function() require("plugin_settings.vim_test") end,
  },

  -- Eager-loaded: AI-pane send helpers in functions/tmux.lua call
  -- VimuxSendText/VimuxSendKeys via vim.fn, which does not trigger
  -- lazy.nvim's `cmd` loader.
  "benmills/vimux",

  -- ============================================================
  -- AI
  -- ============================================================

  -- Use local Ollama AI in VIM
  -- {
  --   "David-Kunz/gen.nvim",
  --   cmd = "Gen",
  --   keys = { { "<leader>q", ":Gen<CR>", mode = "v", desc = "Gen AI prompts" } },
  --   config = function() require("plugin_settings.gen_nvim") end,
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
        -- Restore v3 auto-detection. Without this entry, the custom
        -- list below REPLACES the default and silently disables popups
        -- for g-prefix, z-folds, [/] pairs, operator-pending, etc.
        { "<auto>", mode = "nixsotc" },
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
}, lazy_opts)
