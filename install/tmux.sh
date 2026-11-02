#!/usr/bin/env bash

# # Install dependencies
# sudo apt-get install -y \
#   automake autoconf bison \
#   build-essential pkg-config \
#   libevent-dev libncurses5-dev
#
# timestamp=$(date +%s)
# tmux_source_dir=/tmp/tmux-$timestamp
#
# git clone https://github.com/tmux/tmux.git $tmux_source_dir
#
# cd $tmux_source_dir
#
# tmux_version=3.2a
#
# # Checkout to last stable version
# git checkout $tmux_version
#
# sh autogen.sh
# ./configure --prefix=$HOME/.local/
#
# make -j $(nproc)
# make install
#
#

if c-is-mac; then
  # tmux master (3.9 pre-release) for the side-status Claude sidebar in
  # tmux.conf. Re-running pulls the latest master. Back to stable once 3.9
  # ships: `brew uninstall --force tmux && brew install tmux`.
  if brew list --versions tmux | grep -q HEAD; then
    brew upgrade --fetch-HEAD tmux
  else
    brew unlink tmux 2>/dev/null
    brew install --HEAD tmux || brew link tmux
  fi
else
  sudo pacman -S tmux
fi
