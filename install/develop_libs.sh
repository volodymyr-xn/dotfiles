#!/usr/bin/env bash

if [[ c-is-mac ]]; then
  echo 'TODO MAC'
else
  yes | sudo apt-get install \
    automake autoconf bison \
    autotools-dev curl zlib1g-dev build-essential libssl-dev \
    cmake cmake-data libtool-bin libuv1  \
    libreadline-dev libyaml-dev libsqlite3-dev sqlite3 \
    libxml2-dev libxslt1-dev libcurl4-openssl-dev \
    libffi-dev libncurses5-dev \
    libncursesw5-dev xclip git

  yes | sudo pacman -S automake autoconf bison autotools curl libssl cmake
fi

