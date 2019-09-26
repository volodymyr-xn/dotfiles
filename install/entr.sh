#!/usr/bin/env bash

timestamp=$(date +%s)
destination_dir=/tmp/entr-source-$timestamp

hg clone https://bitbucket.org/eradman/entr $destination_dir

cd $destination_dir

./configure
make test -j $(nproc)
sudo make install
