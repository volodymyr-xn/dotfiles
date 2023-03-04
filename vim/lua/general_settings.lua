--============================================================================
--===================== General settings ====================================
--============================================================================
-- use the space key as our leader. put this near the top of your vimrc
-- Disable default space mapping
vim.api.nvim_set_keymap("n", "<Space>", "<NOP>", { noremap = true, silent = true })

-- Make space Leader
vim.g.mapleader = " "

-- VIM built-in autocomplete options
-- Autocomplete word spelling
-- set spell "kpelllang=en_us
vim.o.complete = vim.o.complete .. ",kspell"
vim.o.completeopt = vim.o.completeopt .. ",preview,menuone"
-- Don't pass messages to |ins-completion-menu|.
vim.o.shortmess = vim.o.shortmess .. "c"

-- set termguicolors to enable highlight groups
vim.opt.termguicolors = true

-- For auto indent filetype plugin indent on
vim.cmd("syntax on")
vim.cmd("filetype plugin on")

-- Use vim, not vi api
vim.o.compatible = false

-- Redraw only when we need to (i.e. don't redraw when executing a macro)
vim.o.lazyredraw = true

-- Indicates a fast terminal connection. More characters will be sent to the
-- screen for redrawing, instead of using insert/delete line commands.
-- Improves smoothness of redrawing when there are multiple windows and the
-- terminal does not support a scrolling region.
-- Experimental
vim.o.ttyfast = true

-- No backup files
vim.o.backup = false

-- No write backup
vim.o.writebackup = false

-- No swap file
vim.o.swapfile = false

-- Encrypted files encryption method
-- set cm=blowfish2 " doesnt work in neovim

-- Command history
vim.o.history = 500

-- Remove escape delay http://www.johnhawthorn.com/2012/09/vi-escape-delays/
vim.o.timeoutlen = 1000
vim.o.ttimeoutlen = 0

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

-- Ignore case in search if term(s) are lowercase
vim.o.ignorecase = true

-- Search with case sensitivity if term(s) are upper or mixed case
vim.o.smartcase = true

-- Turn word wrap off
vim.o.wrap = false

-- Wrap lines at convenient points
vim.o.linebreak = true

-- Indent settings
vim.o.autoindent = true
vim.o.smartindent = true

-- Performance
-- syntax sync maxlines=256
vim.o.syntaxsync = "maxlines:1000"
vim.o.synmaxcol = 200

-- Allow backspace to delete end of line, indent and start of line characters
vim.o.backspace = "indent,eol,start"

vim.o.background = "dark"

-- Base16 hook
if vim.fn.filereadable(vim.env.HOME .. '/.vimrc_background') then
   vim.g.base16colorspace = 256
   vim.cmd('source ~/.vimrc_background')
end

-- vim.cmd("colorscheme base16-horizon-dark")

vim.g.custom_color_character = "#98c379"

-- Access colors present in 256 colorspace
vim.o.termguicolors = true

vim.o.t_8f = [[<Esc>[38;2;%lu;%lu;%lum]]
vim.o.t_8b = [[<Esc>[48;2;%lu;%lu;%lum]]

-- Always show statusline
vim.o.laststatus = 2

-- Always display the tabline, even if there is only one tab
vim.o.showtabline = 2

-- Hide the default mode text (e.g. -- INSERT -- below the statusline)
vim.o.showmode = false

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

-- Highlight a matching [{()}?P] when cursor is placed on start/end character
vim.o.showmatch=true

-- Complete files like a shell.
vim.o.wildmode='list:longest'

-- Show 3 lines of context around the cursor.
vim.o.scrolloff=3

-- Set the terminal's title
vim.o.title=true

-- Yank to vim clipboard
vim.o.clipboard='unnamed'

-- Yank to system clipboard
-- vim.o.clipboard='unnamedplus'

vim.o.foldenable=false
vim.o.foldlevelstart=3
