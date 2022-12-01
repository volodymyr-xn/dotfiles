#!/usr/bin/env bash

# yes | pip3 install meson

if [[ c-is-mac ]]; then
  brew install meson
else
  yes | sudo apt install meson
fi
