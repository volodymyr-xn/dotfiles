#!/usr/bin/env bash

# brew install ack

# sudo apt-get install silversearcher-ag

# sudo apt-get install -y automake pkg-config libpcre3-dev zlib1g-dev liblzma-dev

# Clone fzf repo from gitgub
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf

# Run fzf installation
yes | ~/.fzf/install
