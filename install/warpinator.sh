#!/usr/bin/env bash

# Install build dependencies listed below, note minimum versions:
sudo apt install python3-grpc-tools python3-grpcio -y

# Clone this repo:
dotfiles-install-dir-for-git-project 'warpinator' https://github.com/linuxmint/warpinator.git

# Check out appropriate branch (1.0.6 is current official, master is development)
# git checkout 1.0.6

# Try to build. If this fails, it's probably due to missing dependencies.
# Take note of these packages, install them using apt-get:
dpkg-buildpackage --no-sign
#
# # Once that succeeds, install:
sudo dpkg -i *warp*.deb
#
# # If this fails, make note of missing runtime dependencies (check list below),
# # install them, repeat previous command (apt-get install -f may also work).
