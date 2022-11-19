#!/usr/bin/env bash

yes | sudo apt install build-essential git cmake qt5-default libmpv-dev gcc-8 g++-8 exiv2

timestamp=$(date +%s)
source_dir=/tmp/neovim-$timestamp

git clone https://github.com/easymodo/qimgv.git $source_dir

cd $source_dir

mkdir -p build && cd build

cmake ../ -DCMAKE_INSTALL_PREFIX=/usr/ -DCMAKE_INSTALL_LIBDIR=lib

make -j $(nproc)

sudo make install
