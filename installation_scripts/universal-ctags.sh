#!/usr/bin/env bash

timestamp=$(date +%s)
tags_source_dir=/tmp/universal-ctags-$timestamp

git clone https://github.com/universal-ctags/ctags $tags_source_dir

cd $tags_source_dir

./autogen.sh
./configure
make -j $(nproc)
sudo make install

rm -rf $tags_source_dir
