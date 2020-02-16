#!/usr/bin/env bash

./installation_scripts/develop_libs.sh
./installation_scripts/linuxbrew.sh
./installation_scripts/asdf.sh

./setup/dotfiles.sh
./setup/gnome_settings.sh
./setup/keybindings.sh

./software_packs/packagers.sh
./software_packs/development.sh
# ./software_packs/development_additional.sh
./software_packs/desktop.sh
# ./software_packs/gaming.sh
