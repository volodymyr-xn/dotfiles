#!/usr/bin/env bash

# Install dependencies
# sudo apt-get install -y automake autoconf \
#                         build-essential pkg-config \
#                         libevent-dev libncurses5-dev
#
# timestamp=$(date +%s)
# tmux_source_dir=/tmp/tmux-$timestamp
#
# git clone https://github.com/tmux/tmux.git $tmux_source_dir
#
# cd $tmux_source_dir
#
# # tmux_version=$1
#
# # Checkout to last stable version
# # git checkout $tmux_version
#
# sh autogen.sh
# ./configure --prefix=$HOME/.local/
#
# make -j $(nproc)
#
# sudo make install
# cd -
# rm -rf $tmux_source_dir

brew install tmux
