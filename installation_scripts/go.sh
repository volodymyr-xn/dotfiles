#!/usr/bin/env bash

timestamp=$(date +%s)
go_tmp_binaries_dir=/tmp/go-binaries-$timestamp

mkdir -p $go_tmp_binaries_dir

cd $go_tmp_binaries_dir
sudo curl -O https://storage.googleapis.com/golang/go1.9.1.linux-amd64.tar.gz

tar -xzvf $(ls | tail -n 1)

mv go ~/.go

cd -
rm -rf $go_tmp_binaries_dir
