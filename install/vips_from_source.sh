#!/usr/bin/env bash

# libvips Dependencies
yes | sudo apt-get install git build-essential \
  libxml2-dev libfftw3-dev \
	libmagickwand-dev libopenexr-dev liborc-0.4-0 \
	gobject-introspection libgsf-1-dev \
	libglib2.0-dev liborc-0.4-dev \
  python-gi-dev libgirepository1.0-dev \
  automake libtool swig gtk-doc-tools \
  libgtk2.0-dev flex bison \
  glib-2.0 gmodule-2.0 gobject-2.0

destination_dir=$(dotfiles-tempdir-for 'vips' 'master')

git clone https://github.com/libvips/libvips $destination_dir

cd $destination_dir

git checkout v8.10.5

./autogen.sh
make -j $(nproc)
sudo make install
