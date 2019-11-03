#!/usr/bin/env bash

timestamp=$(date +%s)
vim_source_dir=/tmp/vim-$timestamp

echo "Stating VIM installation"
git clone https://github.com/vim/vim $vim_source_dir

echo "Stating VIM compile process"
cd $vim_source_dir

yes | sudo apt-get build-dep vim-gtk
./configure \
  --enable-gui=gtk2 \
  --enable-gtk2-check \
  --with-x \
  --prefix=~/.local/


make -j $(nproc)
yes | sudo make install

echo "Remove vim source directory $vim_source_dir"
rm -rf $vim_source_dir

echo "Installing VIM Plug"
curl -fLo ~/dotfiles/vim/autoload/plug.vim --create-dirs \
   https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

echo "VIM installed succesfully"
# brew install vim
