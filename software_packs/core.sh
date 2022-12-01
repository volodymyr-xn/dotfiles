#!/usr/bin/env bash

cd $HOME/dotfiles/install

./develop_libs.sh
./homebrew.sh
./asdf.sh
[[ $(c-is-linux) == true ]] && ./flatpak.sh
./meson.sh
./cmake.sh
./htop.sh
