echo "Installing rust"

# Install Rustup
curl https://sh.rustup.rs -sSf | sh
source $HOME/.cargo/env

# Install last stable version of Rust
rustup override set stable
rustup update stable


# # install dependencies
sudo apt-get install cmake libfreetype6-dev libfontconfig1-dev xclip

alacritty_source_tmp_path=/tmp/alacritty-$(date +%s)

# clone alacritty from github
git clone https://github.com/jwilm/alacritty.git $alacritty_source_tmp_path

# build alacritty from source
cd $alacritty_source_tmp_path && cargo build --release

sudo cp $alacritty_source_tmp_path/target/release/alacritty /usr/local/bin/alacritty
cp alacritty.desktop ~/.local/share/applications

rm -rf $alacritty_source_tmp_path
