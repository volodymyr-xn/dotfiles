#!/usr/bin/env bash

version=1.5.1
timestamp=$(date +%s)
destination_file=/tmp/rofi-$version-$timestamp.deb

wget https://launchpad.net/ubuntu/+archive/primary/+files/rofi_$version-1_amd64.deb -O $destination_file

sudo dpkg -i $destination_file
