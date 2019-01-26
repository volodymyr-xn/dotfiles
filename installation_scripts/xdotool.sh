#!/usr/bin/env bash

# sudo apt-get install xdotool

timestamp=$(date +%s)
xdotool_source_dir=/tmp/xdotool-source-$timestamp

echo "Stating installl"
git clone https://github.com/jordansissel/xdotool $xdotool_source_dir

echo "Stating compilation process"
( cd $xdotool_source_dir && make -j 8 && sudo make install -j 8)
