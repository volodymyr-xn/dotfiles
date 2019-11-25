#!/usr/bin/env bash

sudo apt install gtk2-engines-murrine gtk2-engines-pixbuf

destination_dir=$(dotfiles-tempdir-for layan-gtk-theme master)

https://github.com/vinceliuice/Layan-gtk-theme $destination_dir

cd destination_dir

./install
