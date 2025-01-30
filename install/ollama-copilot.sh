#!/usr/bin/env bash

# Proxy that allows you to use ollama as a copilot like Github copilot
# https://github.com/bernardo-bruning/ollama-copilot

go install github.com/bernardo-bruning/ollama-copilot@latest

# Running
# Ensure your $PATH includes $HOME/go/bin or $GOPATH/bin. For example, in ~/.bashrc or ~/.zshrc:
# export PATH="$HOME/go/bin:$GOPATH/bin:$PATH"
# ollama-copilot
#
# Neovim
# Install copilot.vim
# Configure variables
# let g:copilot_proxy = 'http://localhost:11435'
# let g:copilot_proxy_strict_ssl = v:false
