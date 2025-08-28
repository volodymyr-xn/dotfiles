#!/usr/bin/env bash

# Install homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

brew install \
  vim \
  nvim \
  tmux \
  cmake \
  fzf \
  rg \
  mise \
  the_silver_searcher \
  jemalloc \
  fd \
  imagemagic \
  wget \
  vips

brew install --cask ghostty

$HOME/dotfiles/install/oh-my-zsh.sh
