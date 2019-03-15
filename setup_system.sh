#!/usr/bin/env bash

./install_software.sh
./install_dotfiles.sh
./install_executables.sh
./set_dconf.sh

# Create dir for home log
mkdir -p $HOME/.log
