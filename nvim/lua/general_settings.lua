--============================================================================
--===================== General settings ====================================
--============================================================================
-- use the space key as our leader. put this near the top of your vimrc
-- Disable default space mapping
vim.api.nvim_set_keymap("n", "<Space>", "<NOP>", { noremap = true, silent = true })

-- Make space Leader
vim.g.mapleader = " "
vim.g.maplocalleader = ","

-- Vim built-in tree-exploer options
-- vim.g.netrw_banner = 0					-- gets rid of the annoying banner for netrw
-- vim.g.netrw_browse_split=4				-- open in prior window
-- vim.g.netrw_altv = 1					-- change from left splitting to right splitting
-- vim.g.netrw_liststyle=3					-- tree style view in netrw

-- vim.opt.tags = '.tags'

-- VIM built-in autocomplete options
-- Autocomplete word spelling
-- set spell "kpelllang=en_us
vim.o.complete = vim.o.complete .. ",kspell"
-- ',popup' shows LSP resolveSupport documentation inline in the completion
-- popup as items are selected (replaces noice's LSP doc preview behavior).
vim.o.completeopt = vim.o.completeopt .. ",preview,menuone,popup"
-- Don't pass messages to |ins-completion-menu|.
vim.o.shortmess = vim.o.shortmess .. "c"

-- set termguicolors to enable highlight groups
vim.opt.termguicolors = true

-- Default border style for floating windows (LSP hover, diagnostics, pager).
vim.opt.winborder = "rounded"

-- Load per-projekt `.nvim.lua` from the cwd at startup (built-in exrc).
-- Backs the nvim_for_projekts store (e.g. consul_nvim.lua symlinked as
-- .nvim.lua). Run `:trust` once per projekt root the first time nvim is
-- launched there, otherwise the file is ignored for safety.
vim.opt.exrc = true

-- For auto indent filetype plugin indent on
vim.cmd("syntax on")
-- Pretend matchit is loaded BEFORE filetype plugins fire so built-in
-- ftplugins (e.g. $VIMRUNTIME/ftplugin/ruby.vim) populate `b:match_words`
-- with def/end/if/do/case patterns. vim-matchup itself sets this flag in
-- its `plugin/matchup.vim`, but it's lazy-loaded on BufReadPost — too
-- late, because FileType has already fired and the ftplugin skipped the
-- match_words block. Without this, `%`, `ci%`, `ca%` don't see ruby
-- `def...end`/`if...end`/etc.
vim.g.loaded_matchit = 1
vim.cmd("filetype plugin on")

-- Use vim, not vi api
vim.o.compatible = false

-- Redraw only when we need to (i.e. don't redraw when executing a macro)
-- Don't redraw while executing macros or scrolling
-- Helps with removing content jumps when navigating between files in plugins
-- Also improves rendering performance
-- Outdated wisdom. In modern Neovim it causes
-- broken statusline/winbar with laststatus=3, random cursor movement, and unbounded RAM growth
-- when combined with plugins like noice.nvim. Noice's healthcheck explicitly warns against it.
-- vim.o.lazyredraw = true

-- Indicates a fast terminal connection. More characters will be sent to the
-- screen for redrawing, instead of using insert/delete line commands.
-- Improves smoothness of redrawing when there are multiple windows and the
-- terminal does not support a scrolling region.
-- Experimental
-- vim.o.ttyfast = true

-- No backup files
vim.o.backup = false

-- No write backup
vim.o.writebackup = false

-- No swap file
vim.o.swapfile = false
vim.o.backupcopy = "no"

-- Encrypted files encryption method
-- set cm=blowfish2 " doesnt work in neovim

-- Command history
vim.o.history = 500

-- Remove escape delay http://www.johnhawthorn.com/2012/09/vi-escape-delays/
-- vim.o.timeoutlen = 1000
-- vim.o.timeoutlen = 300
-- vim.o.ttimeoutlen = 0

-- Always show cursor
vim.o.ruler = true

-- Highlight current line
vim.o.cursorline = true

-- Show incomplete commands
vim.o.showcmd = true

-- Incremental searching (search as you type)
vim.o.incsearch = true

-- Highlight search matches
vim.o.hlsearch = true

-- Show the native search match count in the bottom bar (e.g. [1/5])
vim.opt.shortmess:remove("S")

-- Ignore case in search if term(s) are lowercase
-- vim.o.ignorecase = true

-- Search with case sensitivity if term(s) are upper or mixed case
vim.o.smartcase = true

-- Keep syntax highlighting on long lines (max column before it stops)
vim.o.synmaxcol = 500

-- Turn word wrap off
vim.o.wrap = false

-- Wrap lines at convenient points
vim.o.linebreak = true

-- Indent settings
vim.o.autoindent = true
vim.o.smartindent = true

-- Performance
vim.cmd [[
  " syntax sync maxlines=500
  syntax sync maxlines=800
  " set synmaxcol=150
  set synmaxcol=200
]]

-- Allow backspace to delete end of line, indent and start of line characters
vim.o.backspace = "indent,eol,start"
-- Access colors present in 256 colorspace
vim.o.termguicolors = true

--vim.o.t_8f = [[<Esc>[38;2;%lu;%lu;%lum]]
--vim.o.t_8b = [[<Esc>[48;2;%lu;%lu;%lum]]

-- Always show statusline
vim.o.laststatus = 2

-- Always display the tabline, even if there is only one tab
vim.o.showtabline = 2

-- Hide the default mode text (e.g. -- INSERT -- below the statusline)
vim.o.showmode = false

-- When a file has been detected to have been changed outside of Vim and
-- it has not been changed inside of Vim, automatically read it again.
-- When the file has been deleted this is not done, so you have the text
-- from before it was deleted.  When it appears again then it is read.
-- timestamp
vim.o.autoread = true

-- Enable mouse
vim.o.mouse = 'a'

--  disable the right-click mouse dialog
vim.o.mousemodel = 'extend'

-- Set number of lines
vim.o.number=true

-- Tabulation settings
vim.o.tabstop=2
vim.o.softtabstop=0
vim.o.shiftwidth=2
vim.o.expandtab=true

-- UTF encoding
vim.o.encoding='utf-8'

-- Autoload files that have changed outside of vim
vim.o.autoread=true

-- Better splits (new windows appear below and to the right)
vim.o.splitbelow=true
vim.o.splitright=true

-- Ensure Vim doesn't beep at you every time you make a mistype
vim.o.visualbell=true

-- Visual autocomplete for command menu (e.g. :e ~/path/to/file)
vim.o.wildmenu=true

-- Automatically rebalance windows on vim resize
vim.cmd('autocmd VimResized * :wincmd =')

-- ========== Additional syntax definitions ========================
-- Highlight crontab and anacrontab files
vim.cmd('autocmd BufNewFile,BufRead crontab,anacrontab set syntax=crontab')

-- Highlight ActiveAdmin rails administation framework templates
vim.cmd('autocmd BufRead,BufNewFile *.arb setfiletype ruby')

-- Map Ren'Py script extensions so the ft-lazy renpy-syntax.nvim trigger fires
-- (the plugin's own detection can't run until it loads). `.rpym` = Ren'Py
-- module files.
vim.filetype.add({ extension = { rpy = "renpy", rpym = "renpy" } })

-- Highlight a matching [{()}?P] when cursor is placed on start/end character
vim.o.showmatch=true

-- Complete files like a shell.
vim.o.wildmode='list:longest'

-- Show 3 lines of context around the cursor.
vim.o.scrolloff=3

-- Set the terminal's title
vim.o.title=true

-- Yank to vim clipboard
-- vim.o.clipboard='unnamed'

-- Always Yank to system clipboard
-- vim.o.clipboard='unnamedplus'

vim.o.foldenable=false
vim.o.foldlevelstart=7

vim.o.pumheight=15

vim.opt.inccommand = "split"

vim.o.shiftround=true

-- Treat dashes "-" as part of words
-- vim.opt.iskeyword:append({ '-' , "@", "$" })

-- Always show the signcolumn, otherwise it would shift the text each time
-- diagnostics appear/become resolved.
vim.o.signcolumn = "yes"
-- vim.o.signcolumn = "number"

--############ NVIM Performance tweaks ########################
-- Assume fast terminal connection
vim.opt.ttyfast=true
-- Reduce redraw frequency
-- vim.opt.updatetime=200
-- vim.opt.updatetime=100
vim.opt.updatetime=200
-- INPUT RESPONSIVENESS ---
-- timeoutlen affects how responsive Neovim feels, especially when typing
-- commands or using keymaps.
-- If you often use which-key.nvim or a similar key-hint plugin:
-- Use a slightly higher value (e.g. 400–500), since those plugins rely on the timeout window to show hints.
vim.opt.timeoutlen=400
vim.opt.ttimeoutlen=10
-- vim.opt.ttimeoutlen=0

vim.opt.smoothscroll=true
vim.opt.showmode=false
