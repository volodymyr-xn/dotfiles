#!/usr/bin/env bash

base16_shell_dir="$HOME/.config/base16-shell"

echo "Installing base16-shell into $base16_shell_dir"
git clone https://github.com/chriskempson/base16-shell.git $base16_shell_dir

source "$HOME/.profile"

pip3 install base16-shell-preview

# base16_gruvbox-dark-medium

base16_horizon-dark
