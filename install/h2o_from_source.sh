#!/usr/bin/env bash

timestamp=$(date +%s)
destination_dir=/tmp/h2o-source-$timestamp
version=2.2.5

mkdir -p $destination_dir
cd $destination_dir

# archive_name=v$version.tar.gz
#
# wget https://github.com/h2o/h2o/archive/$archive_name
#
# tar -xzvf $archive_name

git clone https://github.com/h2o/h2o

# cd h2o-$version
cd h2o

cmake -DWITH_BUNDLED_SSL=on .

make -j $(nproc)

sudo make install
