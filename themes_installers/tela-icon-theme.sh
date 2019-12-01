#!/usr/bin/env bash

destination_dir=$(dotfiles-tempdir-for tela-icon-theme master)

git clone https://github.com/vinceliuice/Tela-icon-theme $destination_dir

cd $destination_dir

./install.sh
