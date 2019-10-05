#!/usr/bin/env bash

# libvips Dependencies
sudo apt-get install git build-essential libxml2-dev libfftw3-dev \
	libmagickwand-dev libopenexr-dev liborc-0.4-0 \
	gobject-introspection libgsf-1-dev \
	libglib2.0-dev liborc-0.4-dev \
  python-gi-dev libgirepository1.0-dev \
  automake libtool swig gtk-doc-tools

timestamp=$(date +%s)
destination_dir=/tmp/libvips-source-$timestamp

git clone https://github.com/jcupitt/libvips.git $destination_dir

cd $destination_dir

./autogen.sh
make -j $(nproc)
sudo make install
