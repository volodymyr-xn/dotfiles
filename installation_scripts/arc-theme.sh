#!/usr/bin/env bash

sudo apt-get install autoconf automake libgtk-3-dev

timestamp=$(date +%s)
arc_theme_source_dir=/tmp/arc-theme-$timestamp

git clone https://github.com/horst3180/arc-theme --depth 1 $arc_theme_source_dir
cd $arc_theme_source_dir

./autogen.sh --prefix=/usr
sudo make install

