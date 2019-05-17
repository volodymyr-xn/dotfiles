#!/usr/bin/env bash

# brew install ack

# sudo apt-get install silversearcher-ag

brew install the_silver_searcher

# sudo apt-get install -y automake pkg-config libpcre3-dev zlib1g-dev liblzma-dev

# Clone fzf repo from gitgub
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf

# Run fzf installation
yes | ~/.fzf/install
