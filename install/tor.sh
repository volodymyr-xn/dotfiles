#!/usr/bin/env bash

yes | sudo apt-get install tor
yes | sudo apt-get install privoxy

sudo systemctl stop tor
sudo systemctl disable tor

sudo systemctl stop privoxy
sudo systemctl disable privoxy
sudo systemctl disable tor@default.service
