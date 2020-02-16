#!/usr/bin/env bash

./setup/dotfiles.sh

# Install software packs
./software_packs/core.sh
./software_packs/development.sh
./software_packs/laptop.sh

./setup/gnome_settings.sh
