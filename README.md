# dotfiles

Config for the machines I work on every day.
It started in 2016 as a vimrc and a tmux.conf and kept growing.
The main machine is an Macbook and ArchLinux desktop PC.
MacBook now, so the macOS side gets most of the attention.

This is a personal setup, not a framework. Paths are hardcoded to
`~/dotfiles`, some scripts assume my hardware, and a few keybindings only
make sense on my keyboards. Take whatever is useful.

## What's in here

```
zshrc, profile, zsh/   zsh with oh-my-zsh, no plugins, custom avit theme
nvim/                  Neovim on lazy.nvim, ~75 plugins plus a few of my own
vim/                   vimrc, and the after/ syntax files nvim shares
tmux/                  tmux.conf, tuned for Ghostty
ghostty/               terminal
herdr/                 herdr, a tmux alternative I'm trying out
hammerspoon/           macOS hotkeys and menubar widgets
config/                ~/.config stuff: kitty, mise, htop, pry, rubocop, fonts
bin/                   ~180 small scripts, all on PATH
native_modules/        Swift sources for helpers that have to be compiled
macos_setup/           Brewfile, defaults, sudoers drop-ins, Docker/Colima
linux_setup/           GNOME, dconf, udev rules, firewall, Wacom, fonts
install/               one script per package, mostly from the Ubuntu years
fixes/                 workarounds for things that broke once
```

## Neovim

Each plugin has its own file in
`lua/plugin_settings/`, keymaps are grouped by area in `lua/keymappings/`.
Leader is space.

`lua/my_plugins/` is the part I wrote myself:

- `memory_cleaner`, `memory_manager`, `memory_monitor` keep long sessions
  from growing forever. They prune idle buffers on a timer, show RSS in the
  statusline, and open a dashboard covering every running nvim.
- `stall_watchdog` notices when the main loop stops draining. Nothing inside
  nvim can report that, so it runs off a libuv timer.
- `onediff` is a small review mode on top of gitsigns. Changed files go into
  quickfix and the hunks are highlighted in the real buffers.
- `shortcuts` (`s?`) lists every keymap, grouped and searchable. `<CR>` jumps
  to where it's defined.
- `ukrainian_layout` keeps normal mode working while the ЙЦУКЕН layout is
  active.
- `fuzzy_picker_selector` switches between Telescope, fzf-lua, fzf.vim and
  fff without changing any keymaps.
- `lsp_card` brings back the old `:LspInfo` window.

`vim.loader` is off on purpose. The comment at the top of `nvim/init.lua`
says why.

## tmux

Prefix is `C-a`. Ghostty's capabilities are declared by hand, so truecolor,
undercurl, OSC 52 clipboard and synchronized output all make it through tmux.
Session switching goes through fzf popups (`c-tmux-switch-session`).

## Hammerspoon

Every global hotkey lives in `hammerspoon/keys.lua`. What the modules do:

- Menubar readouts for CPU/GPU temperature, RAM, swap, power draw, network
  and the heaviest processes. The numbers come from `c-system-sensors-macos`,
  a small Swift binary that reads the SMC directly (Apple Silicon only).
- A caffeine toggle that also blocks sleep on lid close.
- F3/F4 for external monitor brightness over DDC, F9/F10 and the numpad for
  volume.
- Mouse side buttons: App Exposé, Mission Control, opening notifications,
  Quick Look in Finder.
- `Cmd+K` goes back to wherever I was before a notification pulled me away,
  down to the tmux pane.
- Colima's VM only ever grows its share of host RAM, so it gets restarted
  when it's both too big and idle.

After editing anything there, run `c-hammerspoon-reload`. A bare
`hs -c "hs.reload()"` exits 69 every time, even when the reload worked.

## bin

Everything in `bin/` is on PATH. Newer scripts start with `c-` so they
tab-complete as a group and don't shadow real commands. The older ones never
got renamed. Some I use daily:

- `c-kill-process-by-port 3000`
- `c-route-fzf` picks a Rails route and copies its path
- `c-md-to-html` renders Markdown into one self-contained HTML file
- `c-docker-delete-unused-resources`, `c-colima-trim`
- `weather`, `world-clock`

Where new scripts go:

- `bin/` for anything I run by name. No extension.
- `scripts/` when the caller uses an absolute path, or the file needs a real
  extension (the JXA one does).
- `native_modules/<platform>/` for compiled sources. They build into
  `bin_native/<platform>/`, which is gitignored and only on PATH for that OS.
- `dotfiles_setup/` and `install/` for one-shot stuff, never on PATH.

Platform-only scripts carry the platform in the name, like
`c-macos-toggle-lid-sleep`.

## Linux

`linux_setup/` has the GNOME and dconf settings, keybindings, udev rules,
firewall rules, Nautilus scripts and thumbnailers I used on Ubuntu.
`install/` has around 170 install scripts from the same period. Some of it
has probably rotted.

## TODO
- port to Gentoo.
