#!/usr/bin/env bash

cd $HOME/dotfiles/install

./develop_libs.sh
./linuxbrew.sh
./asdf.sh
./flatpak.sh

./tweak_tool.sh
./go.sh
./rclone.sh

./rofi_from_apt.sh
./chromium.sh
./zenity.sh

./zsh.sh
./oh_my_zsh.sh
./vim.sh
./tmux.sh
./gpg_from_homebrew.sh
./base16_shell.sh
./fzf.sh

./silver_searcher.sh
./cmake.sh
./universal-ctags.sh
./at.sh
./htop.sh
./dconf-editor.sh
./fd-find.sh

./install/lm-sensors.sh
./install/psensor.sh

./install/heroku.sh
