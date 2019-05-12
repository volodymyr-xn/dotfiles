#!/usr/bin/env bash

timestamp=$(date +%s)
vim_source_dir=/tmp/vim-$timestamp

echo "Stating VIM installation"
git clone https://github.com/vim/vim $vim_source_dir

echo "Stating VIM compile process"
cd $vim_source_dir

# Enable deb-src in /etc/apt/sources.list in order to allow "build-dep"
# Comments can be removed with
# sudo sed -i~orig -e 's/# deb-src/deb-src/' /etc/apt/sources.list
# Then sudo apt-get update

yes | sudo apt-get build-dep vim-gtk
./configure --enable-gui=gtk2 --enable-gtk2-check --with-x

make -j 4
sudo make install -j 4

echo "Remove vim source directory $vim_source_dir"
rm -rf $vim_source_dir

echo "Installing VIM Plug"
curl -fLo ~/dotfiles/vim/autoload/plug.vim --create-dirs \
   https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

echo "VIM installed succesfully"
# brew install vim
