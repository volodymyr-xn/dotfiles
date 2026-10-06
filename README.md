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

## Neovim in detail

How the custom parts of `nvim/` work and how I drive them. Tuned values
live in `lua/plugin_settings/<name>.lua`, not in the modules.

### Memory

My nvim sessions stay open for days, so memory is managed on purpose.

- `memory_cleaner` loads at startup and owns every timer. Buffers are
  stamped on `BufLeave`, and a periodic sweep unloads the ones idle for a
  few hours, skipping visible, modified and special buffers. The same sweep
  stops LSP clients left without a buffer, and hidden fugitive blames are
  wiped. Crossing the RSS limit warns once, not on every tick.
- `:MemClearAll` (`se`) is the manual reset: it stops every treesitter
  parser and LSP client, wipes fugitive buffers and runs the GC.
  `:MemClearTreesitter`, `:MemClearFugitive` and `:MemClearLsp` do one part.
- `memory_monitor` is the `󰘚 234M` lualine chip. It samples on its own
  timer, so a redraw never shells out to `ps`.
- `memory_manager` (`sv`, `:MemDashboard`) loads on first use. It finds
  every running nvim by its server socket and shows one row per process:
  RSS, subsystems, uptime, buffers, parsers, and peak and trend over 24h.
  `<Tab>` expands a process into its buffers, `u`/`w` unload or wipe one,
  `X` (after a confirm) unloads every idle hidden buffer in every instance,
  `x` kills a stuck instance,
  `?` lists the rest. Remote calls go through `nvim --remote-expr` with a
  hard timeout. In-process RPC had none, so one wedged sibling froze the
  editor that opened the dashboard.

### Stall watchdog

While the main loop is stuck, every queued `vim.schedule` callback stays
alive with whatever it captured. A plugin polling on a short timer grew one
instance to 13 GB over eight days that way. nvim can't report this itself,
because `vim.notify` is exactly what stopped running.

The watchdog runs in a libuv timer, which keeps firing. It keeps one probe
in the queue, and when the probe hasn't come back after five minutes it
sends an OS notification with the PID and cwd, then repeats hourly. Events
go to `stdpath("log")/stall_watchdog.log`, which survives the restart. It
only reports and never cancels anything, because a prompt left open is a
legitimate stall.

### OneDiff

`M` toggles a review of the working-tree diff. There's no diff tab: changed
files go into a quickfix list and hunks are highlighted in the real buffers,
so fixing something mid-review is plain editing. The list refreshes on
write.

- `<Tab>`/`<S-Tab>` walk hunks across all files, `(`/`)` within one.
- `<C-S-M>` toggles deleted lines as virtual lines.
- `dd` in the list hides a file until the session is closed.
- `sf` highlights changed lines without opening the list.

Deleted files are listed but skipped. Setting `position` in
`plugin_settings/onediff.lua` moves the list to a sidebar.

### Keymaps

- `shortcuts` (`s?`) reads mappings live from nvim, global and
  buffer-local, so the list can't drift from what's bound. The source file
  comes from `debug.getinfo` on Lua callbacks, or from the script id on
  Vimscript maps. `s` cycles grouping (file, key prefix, mode), `/`
  filters, `<CR>` opens the definition.
- `ukrainian_layout` needs two mechanisms. `langmap` covers built-in
  commands, but it applies after mapping resolution, so custom maps never
  see it. Those get a Cyrillic twin instead, re-synced as lazy.nvim loads
  plugins and per buffer on `FileType` and `LspAttach`. In insert and
  cmdline modes only modifier chords are mirrored, so a `jk` twin can't
  fire while I type "ол". `:UkrainianLayoutSync` re-runs it.

### Pickers

Finder keymaps call `custom_file_selectors/<backend>.lua`. Telescope,
fzf-lua, fzf.vim and fff each implement the same functions, and
`fuzzy_picker_selector` decides which one runs. `:PickerSwitch` cycles,
`:PickerSet <name>` picks one. The choice lives in a state file that's
re-read on every call, so all open nvims agree on it. fff falls back to
fzf-lua for whatever it can't do.

### tmux and AI agents

`functions/tmux_panes.lua` keeps the pane inventory for the current window.
A pane is free only when a shell is in the foreground and no `claude` or
`agent` process runs under it. Claude Code puts `✳` in the pane title when
idle and a braille spinner while working, which is how idle and busy are
told apart.

- `` <Leader>` `` sends `@path` of the current file to an agent pane. In
  visual mode it sends the selection as a fenced block, and `sm` does the
  same for the current line.
- With two or more agent panes, a Telescope picker lists them with idle or
  busy icons.
- Multi-line text uses the agent's newline key (`S-Enter` for Claude),
  so the prompt is composed but not sent and I can type the question after.
- vim-test runs through `functions/test_runner.lua`. Vimux takes the first
  other pane, which kept being an agent or a server. This picks an idle pane
  or splits a new one titled `vim-test`.

### Smaller pieces

- `lsp_card` (`sc`) is lspconfig's old `:LspInfo` window, copied from
  v0.1.8, plus each server's RSS, and treesitter and diagnostics sections
  for the current buffer.
- `git_diff_popup` (`sd`) shows the file's `git diff` in a float, with the
  cursor on the current line.
- `markdown_html_preview` (`sh`) renders the buffer with `c-md-to-html` and
  opens it in the browser.
- `ruby_component_toggle` (`s1` to `s4`) jumps between a component's `.rb`,
  `.html.erb`, stylesheet and `.js`.
- `renpy_tools` runs and lints a Ren'Py project in a tmux pane and finds
  the SDK and project root itself.
- `lua/ui2.lua` turns on nvim 0.12's experimental cmdline and messages.
- Workarounds for upstream bugs sit behind
  `TempFixActive(label, "YYYY-MM-DD")`. After that date the workaround
  turns itself off and warns, so it gets deleted instead of staying
  forever. The nvim 0.12 treesitter guard in `functions/nvim_compat.lua`
  is one.
- Lazy commands like `:GitDiffPopup` are stubs that `require` the module
  and call it directly. Re-dispatching through `vim.cmd` once looped
  forever.
