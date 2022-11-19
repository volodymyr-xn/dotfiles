# #!/usr/bin/env bash
#
# yes | sudo apt install libdbus-1-dev libxcursor-dev libxrandr-dev libxi-dev libxinerama-dev libgl1-mesa-dev libxkbcommon-x11-dev libfontconfig-dev libpython-dev
#
# destination_dir=$(dotfiles-tempdir-for 'kitty' 'master')
#
# git clone https://github.com/kovidgoyal/kitty $destination_dir
#
# cd $destination_dir
#
# export PKG_CONFIG_PATH=/usr/lib/x86_64-linux-gnu/pkgconfig:$PKG_CONFIG_PATH
# python3 setup.py linux-package
#
# make -j $(nproc)
# # sudo make install
# ./kitty/launcher/kitty
