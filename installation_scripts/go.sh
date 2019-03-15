#!/usr/bin/env bash

timestamp=$(date +%s)
go_tmp_binaries_dir=/tmp/go-binaries-$timestamp
version=1.12.1

mkdir -p $go_tmp_binaries_dir

git clone https://go.googlesource.com/go $go_tmp_binaries_dir
cd $go_tmp_binaries_dir

git checkout go$version

cd src

./all.bash

cd -
rm -rf $go_tmp_binaries_dir

# brew install go

# git clone https://go.googlesource.com/go
# cd go
# git checkout go1.12.1
# cd src
# ./all.bash
