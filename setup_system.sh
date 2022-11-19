#!/usr/bin/env bash

./setup/dotfiles.sh

./software_packs/core.sh
./software_packs/basic.sh
./software_packs/development.sh
./software_packs/development_additional.sh
./software_packs/desktop.sh
# ./software_packs/gaming.sh

# Create dir for home log
mkdir -p $HOME/.log
