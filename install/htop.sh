#!/usr/bin/env bash

if [[ c-is-mac ]]; then
  brew install htop
else
  sudo apt install htop -y
fi
