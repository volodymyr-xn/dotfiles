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

`init.lua` puts `modules/` and `lib/` on the require path, loads the modules
that start something on load, and loads `keys.lua` last. Every global hotkey
lives in `keys.lua`. `modules/` holds the features, `lib/` the shared pieces
with no bindings of their own (canvas banners and dropdown panels, the helper
process streams, number formatting). `lib/` never requires a module.
`attic/` keeps old versions for reference, outside the require path so they
can't load by accident.

Menubar, right to left:

- `system_stats` shows CPU load, die temperature, RAM, swap and power draw.
  Clicking it opens a panel with the rest, GPU included.
- `network_stats` shows upload and download for whichever interface has the
  default route. The panel shows the address, Wi-Fi signal and totals.
- `process_stats` is a gear that opens the heaviest processes by CPU, energy
  and memory, refreshed every second while the panel is open.
- `claude_stats` lists every Claude Code profile: limit rings, sessions,
  token usage by model. Clicking a session jumps to its terminal and tmux
  pane. It reads a couple of files from my `control_panel` repo, so it won't
  work as is anywhere else.

The bar items are drawn by `c-system-sensors-macos`, a Swift helper that
reads the SMC directly (Apple Silicon only). The process and Claude panels
get their data from `c-process-stats-macos` and `c-claude-stats-macos`.
Build all of them with `dotfiles_setup/build_native_modules.sh`.

Keyboard and mouse:

- `brightness`: F3/F4 set external monitor brightness over DDC with
  `m1ddc` and show a small HUD. With no external monitor they fall back to
  the built-in one.
- `media_keys`: F9/F10 and numpad `-`/`+` for volume, numpad `*` mutes,
  numpad `0` plays/pauses.
- `mouse_side_buttons`: the bottom button opens App Exposé, or Mission
  Control with `Cmd`. The top one does Quick Look in Finder and `smart_nav`
  everywhere else. `Cmd+Shift+N` turns the mapping off for games.
- `smart_nav` opens the top notification if there is one, otherwise goes
  back to where I was, otherwise opens Mission Control.
- `cycle_app_windows`: `` Cmd+` `` cycles the front app's windows, whatever
  the keyboard layout.
- `swich_monitor_focus`: `Cmd+Alt+M` moves the mouse and focus to the next
  monitor.
- `Cmd+E` opens App Exposé and `Cmd+Shift+L` puts the Mac to sleep, both
  straight from `keys.lua`.

Notifications. When an agent finishes, a notification pulls me to its tmux
pane, and these handle the round trip:

- `click_notification`: `Cmd+L` clicks the top notification.
- `notify_return` saves where I was before the jump. `Cmd+K` within three
  minutes goes back to that app, down to the tmux pane.
- `dismiss_notifications`: `Cmd+I` clears every notification on screen.

Background:

- `caffeine`: `Cmd+M` keeps the Mac awake, lid closed included (that part
  needs `macos_setup/sudoers.d/pmset-disablesleep`). It's always off after
  a reload.
- `colima_autotrim`: Colima's VM only ever grows its share of host RAM, so
  every 15 minutes it gets restarted if it's both too big and idle.

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
