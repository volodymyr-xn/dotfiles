#!/usr/bin/env bash

yes | sudo apt-get install autoconf automake libgtk-3-dev \
                           sassc optipng inkscape \
                           gnome-themes-standard gnome-shell-extensions

timestamp=$(date +%s)
arc_theme_source_dir=/tmp/arc-theme-$timestamp

git clone https://github.com/arc-design/arc-theme --depth 1 $arc_theme_source_dir
cd $arc_theme_source_dir


./autogen.sh --prefix=/usr
sudo make install
