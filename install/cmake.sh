#!/usr/bin/env bash

if [[ c-is-mac ]]; then
  brew install cmake
else
  yes | sudo apt install cmake
fi
