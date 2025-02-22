#!/usr/bin/env bash

# Clone asdf master
echo "Install asdf from master branch"
git clone https://github.com/asdf-vm/asdf.git ~/.asdf

cd ~/.asdf
git checkout "v0.14.1"

echo "Asdf installation finished"
