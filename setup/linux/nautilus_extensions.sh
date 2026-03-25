#!/usr/bin/env bash

set -u

scripts_dir="$HOME/.local/share/nautilus/scripts"

# if [[ -d "$scripts_dir"  && -L "$scripts_dir"  ]]; then
#   rmdir "$HOME/.local/share/nautilus/scripts"
# fi

ln -nfs "$HOME/dotfiles/software_extensions/nautilus/scripts"  "$HOME/.local/share/nautilus/scripts"

ln -nfs "$HOME/dotfiles/software_extensions/nautilus/script-accels"  "$HOME/.config/nautilus/script-accels"
