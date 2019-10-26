#!/usr/bin/env bash

# Install Rustup
curl https://sh.rustup.rs -sSf | sh
source $HOME/.cargo/env

# Install last stable version of Rust
rustup override set stable
rustup update stable

# install dependencies
yes | sudo apt-get install cmake libfreetype6-dev libfontconfig1-dev xclip

alacritty_source_tmp_path=/tmp/alacritty-$(date +%s)

# clone alacritty from github
git clone https://github.com/jwilm/alacritty $alacritty_source_tmp_path

# build alacritty from source
cd $alacritty_source_tmp_path && cargo build --release

yes | sudo cp -rf $alacritty_source_tmp_path/target/release/alacritty /usr/local/bin/alacritty
sudo cp extra/logo/alacritty-term.svg /usr/share/pixmaps/Alacritty.svg
sudo desktop-file-install extra/linux/alacritty.desktop
sudo update-desktop-database

# rm -rf $alacritty_source_tmp_path
