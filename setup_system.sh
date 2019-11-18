#!/usr/bin/env bash

./installation_scripts/develop_libs.sh
./installation_scripts/linuxbrew.sh
./installation_scripts/asdf.sh

./setup/dotfiles.sh
./setup/software.sh
./setup/dconf.sh

# Create dir for home log
mkdir -p $HOME/.log
