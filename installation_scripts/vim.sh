#!/usr/bin/env bash

timestamp=$(date +%s)
vim_source_dir=/tmp/vim-$timestamp

echo "Stating installl"
git clone https://github.com/vim/vim $vim_source_dir

echo "Stating compile process"
( cd $vim_source_dir && make -j 8 && sudo make install -j 8)

echo "Remove vim source directory $vim_source_dir"
rm -rf $vim_source_dir

echo "Installing VIM Plug"
curl -fLo ~/dotfiles/vim/autoload/plug.vim --create-dirs \
   https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
