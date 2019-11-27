#!/usr/bin/env bash

cd $HOME/dotfiles/install

./develop_libs.sh
./linuxbrew.sh

./oh_my_zsh.sh
./fzf.sh
./cmake.sh
./at.sh
./imagemagic.sh
./base16_shell.sh
./htop.sh

./silver_searcher.sh
./jemalloc.sh

./asdf.sh
./ruby_asdf.sh
./nodejs_asdf.sh
./postgres_asdf.sh
./redis_asdf.sh
./crystal_asdf.sh

./universal-ctags.sh

./zsh.sh
./tmux.sh
./vim.sh
./gpg_from_homebrew.sh

./alacritty.sh
