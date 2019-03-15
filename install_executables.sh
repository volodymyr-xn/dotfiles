#!/usr/bin/env bash

# Create dir for executables
mkdir -p $HOME/.local/bin

BINARIES_DIR=$HOME/dotfiles/bin/

executables_to_symlink="toggle-display-focus xcopy man"

for executable in $executables_to_symlink; do
  ln -nfs $BINARIES_DIR/$executable $HOME/.local/bin/$executable
done
