#!/usr/bin/env bash

# Dependencies
yes | sudo apt install gtk2-engines-murrine gtk2-engines-pixbuf

destination_dir=$(dotfiles-tempdir-for white-sur master)

git clone https://github.com/vinceliuice/Mojave-gtk-theme $destination_dir

cd $destination_dir

./install.sh
