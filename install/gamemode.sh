#!/usr/bin/env bash

destination_dir=/tmp/gamemode-$(timestamp-ms)

sudo apt install meson libsystemd-dev pkg-config ninja-build libdbus-1-dev dbus-user-session

git clone https://github.com/FeralInteractive/gamemode $destination_dir

cd $destination_dir

git checkout 1.6.1

yes | ./bootstrap.sh
