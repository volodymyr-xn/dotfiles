# ack.nvim

Run your favorite search tool (ack, ag, ripgrep, ...) from Neovim and get the
results in the quickfix window, with mappings for opening them in splits and
tabs.

A Lua rewrite of [ack.vim](https://github.com/mileszs/ack.vim): same commands,
same behaviour, but configured through `setup()` instead of global variables,
loaded lazily on first use, and able to collapse duplicate per-match results.

## Requirements

Neovim 0.7+ and one of `rg`, `ag`, or `ack` on your `$PATH`.

`rg`, `ag`, `ack-grep` and `ack` are autodetected in that order; set `search_command`
to pick a different program or different flags.

## Installation

This copy lives inside the dotfiles at `nvim/plugins/ack.nvim` and is loaded
by lazy.nvim through the `dev` path configured in `nvim/lua/plugins_install.lua`,
with the options in `nvim/lua/plugin_settings/ack.lua`.

Standalone, with [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "volodymyr-xn/ack.nvim",
  cmd = { "Ack", "AckAdd", "AckFromSearch", "LAck", "LAckAdd",
          "AckFile", "AckHelp", "LAckHelp", "AckWindow", "LAckWindow" },
  opts = {
    search_command = "rg --column --no-heading --with-filename --color never --follow",
  },
}
```

`setup()` is optional — the commands work on the defaults without it.

## Commands

All commands take `[options] {pattern} [{directories}]` and accept a bang,
which keeps the cursor in place instead of jumping to the first result (like
`:grep!`). With no pattern, the word under the cursor is searched.

| Command | What it does |
| --- | --- |
| `:Ack` | Search recursively into the quickfix list |
| `:AckAdd` | Append to the existing quickfix list |
| `:LAck` / `:LAckAdd` | The same, for the window's location list |
| `:AckFile` | List matching file names (`-g`) rather than lines |
| `:AckFromSearch` | Search for the last search register pattern |
| `:AckHelp` / `:LAckHelp` | Search the help files on `runtimepath` |
| `:AckWindow` / `:LAckWindow` | Search only the files open in this tab page |

## Result window mappings

`o` open, `O` open and close the list, `go` preview, `t` / `T` new tab,
`h` / `H` horizontal split, `v` / `gv` vertical split, `q` close.
The uppercase variants keep focus on the results list.

## Configuration

```lua
require("ack").setup({
  -- Shell command that performs the search: program plus flags, no pattern.
  -- Output must match `file:line[:column]:text`. nil autodetects rg / ag /
  -- ack-grep / ack.
  search_command = nil,
  -- Flags appended to a bare ack binary when autodetected.
  default_options = " -s -H --nopager --nocolor --nogroup --column",
  -- Run searches in the background through vim-dispatch.
  use_dispatch = false,
  -- Apply the result mappings in the quickfix / location list window.
  apply_qmappings = true,
  apply_lmappings = true,
  -- How the results window is opened.
  qhandler = "botright copen",
  lhandler = "botright lopen",
  -- Highlight the pattern in the opened buffers.
  highlight = false,
  -- Close the results window after jumping to an entry.
  autoclose = false,
  -- Search the word under the cursor when no pattern is given.
  use_cword_for_empty_search = true,
  -- Keep one entry per file+line. nil enables it for `--vimgrep` programs,
  -- which report every match on a line separately.
  remove_duplicates = nil,
  -- Result window mappings, merged over the defaults.
  mappings = {},
})
```

Set `vim.g.ackpreview = true` to make `j`/`k` in the results window preview
the entry under the cursor.

See `:help ack.nvim` for the full reference.

## Credits

Derived from [ack.vim](https://github.com/mileszs/ack.vim) by Miles Sterrett
and its contributors, itself based on Antoine Imbert's "ack and Vim
Integration" post. Distributed under the same license terms as Vim itself
(see [LICENSE](LICENSE)).
