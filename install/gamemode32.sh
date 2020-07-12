#!/usr/bin/env bash

destination_dir=/tmp/gamemode-$(timestamp-ms)

yes | sudo apt-get install libsystemd-dev:i386 meson libsystemd-dev pkg-config ninja-build git libdbus-1-dev libdbus-1-dev:i386 gcc-multilib

git clone https://github.com/FeralInteractive/gamemode $destination_dir

cd $destination_dir

RELEASE_VERSION=1.5.1

git checkout $RELEASE_VERSION

export CFLAGS='-m32'
export PKG_CONFIG_PATH='/usr/lib32/pkgconfig'

meson build32 -Dwith-daemon=false -Dwith-examples=false -Dwith-systemd=false --prefix=/usr --libdir lib32
sed -i 's/x86_64-linux-gnu\/libdbus/i386-linux-gnu\/libdbus/g' build32/build.ninja
ninja -C build32

sudo ninja -C build32 install
sudo ldconfig
