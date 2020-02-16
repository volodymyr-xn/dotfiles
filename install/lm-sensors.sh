#!/usr/bin/env bash

# sudo apt install lm-sensors
brew install lm-sensors

sudo yes | apt install hddtemp

yes | sudo sensors-detect
