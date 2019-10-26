#!/usr/bin/env bash

version=${1:-"2.2.6"}
deb_tmp_path=/tmp/vagrant-$version.deb

wget https://releases.hashicorp.com/vagrant/$version/vagrant_$version\_x86_64.deb -O $deb_tmp_path

yes | sudo dpkg -i $deb_tmp_path
