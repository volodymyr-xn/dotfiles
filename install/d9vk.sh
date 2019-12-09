#!/usr/bin/env bash

destination_dir=$(dotfiles-tempdir-for 'd9vk' 'master')

git clone https://github.com/Joshua-Ashton/d9vk $destination_dir

cd $destination_dir

export WINEPREFIX=$HOME/.wine
chmod +x ./setup_dxvk.sh
./setup_dxvk.sh install
