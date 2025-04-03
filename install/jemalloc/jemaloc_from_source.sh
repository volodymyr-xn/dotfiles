#!/usr/bin/env bash

timestamp=$(date +%s)
destination_dir=/tmp/jemalloc-$timestamp

git clone https://github.com/jemalloc/jemalloc $destination_dir

cd $destination_dir

last_tag=$(git tag | tail -n 1)

# echo "Last tag: $last_tag"

git checkout "$last_tag"

./autogen.sh

make dist
make -j $(nproc)
sudo make install
