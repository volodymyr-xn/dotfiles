#!/usr/bin/env bash

# destination_dir_path=/tmp/phantomjs/ #-$(timestamp-ms)
# version=2.1.1
# filename=phantomjs-$version-linux-x86_64.tar.bz2
# full_path="${destination_dir_path}${filename}"
#
# echo "$full_path"
#
# mkdir $destination_dir_path
#
# wget https://bitbucket.org/ariya/phantomjs/downloads/$filename -O $full_path
#
# sudo tar -xvjf \
#          "$full_path" \
#          -C /opt/
#
# sudo ln -sf \
#         /opt/phantomjs-$version-linux-x86_64/bin/phantomjs \
#         /usr/local/bin/phantomjs

yes | sudo apt install phantomjs
