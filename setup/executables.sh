#!/usr/bin/env bash

# Create dir for executables
mkdir -p $HOME/.local/bin

ln -nfs $HOME/dotfiles/bin/* $HOME/.local/bin/
