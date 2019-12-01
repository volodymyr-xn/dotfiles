#!/usr/bin/env bash

destination_dir=$(dotfiles-tempdir-for 'dxvk' 'master')

git clone https://github.com/doitsujin/dxvk $destination_dir

cd $destination_dir

export WINEPREFIX=$HOME/.wine
chmod +x ./setup_dxvk.sh
./setup_dxvk.sh install
