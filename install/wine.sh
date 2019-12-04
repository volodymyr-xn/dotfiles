#!/usr/bin/env bash

# sudo apt install wine

# Enable 32 bit architecture
sudo dpkg --add-architecture i386

wget -nc
sudo apt-key add winehq.key

yes | wget -q https://dl.winehq.org/wine-builds/winehq.key -O- | sudo apt-key add -


# For ubuntu 19.10
sudo apt-add-repository 'deb https://dl.winehq.org/wine-builds/ubuntu/ eoan main'

sudo apt-get install --install-recommends winehq-stable
