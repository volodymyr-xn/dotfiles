#!/usr/bin/env bash

yes | sudo apt-get install tor privoxy

sudo systemctl stop tor
sudo systemctl disable tor
sudo systemctl disable tor@default.service

sudo systemctl stop privoxy
sudo systemctl disable privoxy
