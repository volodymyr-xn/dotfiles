#!/usr/bin/env bash

timestamp=$(date +%s)
destination_dir=/tmp/cmus-source-$timestamp

mkdir -p $destination_dir
cd $destination_dir

git clone https://github.com/cmus/cmus $destination_dir

cd $destination_dir

./configure

make -j $(nproc)
sudo make install

# or brew install cmus
