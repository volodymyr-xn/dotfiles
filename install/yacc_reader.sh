#!/usr/bin/env bash

# TODO
destination_dir=$(dotfiles-tempdir-for "yacc-reader" "master")

# unrar-free
  # libqt5script5 \

sudo apt install \
  p7zip-full \
  libunarr-dev \
  qt5-default \
  qtmultimedia5-dev \
  libqt5widgets5 \
  qtscript5-dev \
  libqt5scripttools5 \
  qtdeclarative5-dev

git clone \
  https://github.com/YACReader/yacreader \
  $destination_dir


cd $destination_dir/YACReader
qmake PREFIX=/usr/local CONFIG+=no_pdf CONFIG+=unarr
make -j $(nproc)
sudo make install

cd $destination_dir/YACReaderLibrary
qmake PREFIX=/usr/local CONFIG+=no_pdf CONFIG+=unarr
make -j $(nproc)
sudo make install
