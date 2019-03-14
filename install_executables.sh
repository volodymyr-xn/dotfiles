#!/usr/bin/env bash

# Create dir for executables
mkdir -p $HOME/bin

BINARIES_DIR=$HOME/dotfiles/bin/

ln -nfs $BINARIES_DIR/toggle-display-focus $HOME/bin/toggle-display-focus
ln -nfs $BINARIES_DIR/xcopy $HOME/bin/xcopy

mkdir $HOME/.log
