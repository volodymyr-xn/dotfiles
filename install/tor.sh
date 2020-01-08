#!/usr/bin/env bash

yes | sudo apt-get install tor privoxy

sudo systemctl stop tor
sudo systemctl disable tor
sudo systemctl disable tor@default.service

sudo systemctl stop privoxy
sudo systemctl disable privoxy

# to enable Privoxy connection to Tor

# Add this to `/etc/privoxy/config`:
# `forward-socks4a / localhost:9050 .`

# `9050` is tor default port
