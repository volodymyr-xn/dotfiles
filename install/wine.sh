#!/usr/bin/env bash

# sudo apt install wine

# Enable 32 bit architecture
sudo dpkg --add-architecture i386

wget -nc
sudo apt-key add winehq.key

yes | wget -q https://dl.winehq.org/wine-builds/winehq.key -O- | sudo apt-key add -

# For ubuntu 19.10
sudo apt-add-repository 'deb https://dl.winehq.org/wine-builds/ubuntu/ focal main'

sudo apt-get install --install-recommends winehq-stable
sudo apt install wine-staging wine-staging-amd64 wine-staging-i386:i386
sudo apt install wine-devel wine-devel-amd64 wine-devel-i386:i386


# Additional dependencies
sudo apt-get install libgnutls30:i386 libldap-2.4-2:i386 \
  libgpg-error0:i386 libxml2:i386 libasound2-plugins:i386 \
  libsdl2-2.0-0:i386 libfreetype6:i386 libdbus-1-3:i386 libsqlite3-0:i386

# for supreme commander
winetricks dlls xact
