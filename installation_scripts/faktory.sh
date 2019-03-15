#!/usr/bin/env bash

# timestamp=$(date +%s)
# destination_dir=/tmp/faktory-$timestamp
#
# # git clone https://github.com/contribsys/faktory $destination_dir
#
# mkdir -p $destination_dir
# cd $destination_dir
# wget https://github.com/contribsys/faktory/releases/download/v0.9.6-1/faktory_0.9.6-1_amd64.deb
#
# yes | sudo apt-get install redis-server
# yes | sudo dpkg -i faktory_0.9.6-1_amd64.deb

brew install faktory

# ./autogen.sh
# make dist
# make -j 4
# sudo make install -j 4
