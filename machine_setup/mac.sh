#!/usr/bin/env bash

# Install homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

brew bundle --file $HOME/dotfiles/machine_setup/Brewfile


$HOME/dotfiles/install/oh-my-zsh.sh
