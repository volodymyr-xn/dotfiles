#!/usr/bin/env bash

timestamp=$(date +%s)
destination_dir=/tmp/jemalloc-$timestamp

git clone https://github.com/jemalloc/jemalloc $destination_dir

cd $destination_dir

./autogen.sh

make dist
make -j $(nproc)
sudo make install
