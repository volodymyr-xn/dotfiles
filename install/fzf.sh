#!/usr/bin/env bash

# Search engine for FZF
brew install the_silver_searcher

# Alternative search engine
# brew install ack

# Build dependencies for FZF
# sudo apt-get install -y automake pkg-config libpcre3-dev zlib1g-dev liblzma-dev

# Clone fzf repo from gitgub
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf

# # Run fzf installation
yes | ~/.fzf/install --xdg
