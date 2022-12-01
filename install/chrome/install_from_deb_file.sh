#!/usr/bin/env bash

chrome_deb_path=/tmp/google-chrome-stable_current_amd64.deb

wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O $chrome_deb_path

sudo dpkg -i $chrome_deb_path
rm $chrome_deb_path
