#!/usr/bin/env bash

version=1.5.1
timestamp=$(date +%s)
destination=/tmp/rofi-sources-$timestamp

git clone --recursive https://github.com/DaveDavenport/rofi $destination

cd $destination

autoreconf -i

mkdir build && cd build
../configure

make -j (nproc)
sudo make install

# TO BE CONTINUED...
# ON NEWER UBUNTU VERSION
