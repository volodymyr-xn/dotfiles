# Keep PATH entries unique. macOS path_helper, brew shellenv and nested
# shells (herdr/tmux panes) re-add directories that are already present;
# on a duplicate zsh keeps the first occurrence, so prepends still win.
typeset -U path PATH

. "$HOME/.cargo/env"
