#!/usr/bin/env bash

timestamp=$(date +%s)
destination_dir=/tmp/h2o-source-$timestamp
version=2.2.5

mkdir -p $destination_dir
cd $destination_dir

wget https://github.com/h2o/h2o/archive/v$version.tar.gz

tar -xzvf $(ls | tail -n 1)

cd h2o-$version

cmake -DWITH_BUNDLED_SSL=on .

make -j 8
sudo make install -j 8

