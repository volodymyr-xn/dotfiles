#/usr/bin/env bash

# A modern audio book player
# https://flathub.org/apps/details/com.github.geigi.cozy
flatpak install com.github.geigi.cozy

# destination_dir=$(dotfiles-tempdir-for 'cozy' 'master')
# git clone https://github.com/geigi/cozy.git $destination_dir
# #
# # # Build dependencies
# pip3 install meson ninja peewee pycairo PyGObject mutagen
# sudo apt install gstreamer1.0-plugins-good
# #
# cd $destination_dir
# #
# install_to="$HOME/.local"
# build_directory=$destination_dir/build
# #
# mkdir -p $build_directory
# #
# meson $build_directory --prefix=$install_to
# ninja -C $build_directory install
