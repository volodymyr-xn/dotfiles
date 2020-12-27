#!/usr/bin/env bash

# Dependencies
yes | sudo apt install gtk2-engines-murrine gtk2-engines-pixbuf

destination_dir=$(dotfiles-tempdir-for layan-gtk-theme master)

git clone https://github.com/vinceliuice/Layan-gtk-theme $destination_dir

cd $destination_dir

./install
