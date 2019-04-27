#!/usr/bin/env bash

./installation_scripts/develop_libs.sh
./installation_scripts/linuxbrew.sh
./installation_scripts/asdf.sh
./install_dotfiles.sh

./install_software.sh
./install_executables.sh
./set_dconf.sh

# Create dir for home log
mkdir -p $HOME/.log
