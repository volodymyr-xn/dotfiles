#!/usr/bin/env bash

timestamp=$(date +%s)
destination_dir=/tmp/zsh-$timestamp

echo 'Download zsh source code to $destination_dir'

sudo apt-get install -y \
                      git-core \
                      gcc \
                      make \
                      autoconf \
                      yodl \
                      libncursesw5-dev \
                      texinfo

# Download and unapack zsh source code to tmp directory
git clone https://github.com/zsh-users/zsh $destination_dir
cd $destination_dir

git checkout $(git tag | tail -n 1)

./Util/preconfig

./configure

make -j $(nproc)
make check -j $(nproc)
sudo make install

cd ..

# Remove tmp directory with source code
rm -rf $destination_dir

# Add Zsh to the list of shells in /etc/shells.
which zsh | sudo tee -a /etc/shells

# Set Zsh as the default shell for the current user.
sudo chsh -s $(which zsh)

echo 'ZSH installation done'
echo $(zsh --version)
