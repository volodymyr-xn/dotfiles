#!/usr/bin/env bash

set -euo pipefail

destination_dir=$(dotfiles-tempdir-for 'dxvk' 'master')

git clone https://github.com/doitsujin/dxvk $destination_dir

cd $destination_dir

git checkout v1.8

chmod +x ./setup_dxvk.sh
WINEPREFIX=/home/tech/StandaloneApps/Photoshop/Wine/WinePrefixes/wine-experiment ./setup_dxvk.sh install
