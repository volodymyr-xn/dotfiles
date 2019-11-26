#!/usr/bin/env bash

timestamp=$(date +%s)
destination_dir=/tmp/dunst-$timestamp

git clone https://github.com/dunst-project/dunst.git $destination_dir

cd $destination_dir

make -j $(nproc)
sudo make install
