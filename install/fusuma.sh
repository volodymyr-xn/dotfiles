#!/usr/bin/env bash

# Multitouch gestures with libinput driver on Linux
# https://github.com/iberianpig/fusuma

# Dependencies
yes | sudo apt install libinput-tools xdotool

mkdir -p ~/.config/fusuma

gem install fusuma

# If Touchpad not working in GNOME
# Ensure the touchpad events are being sent to the GNOME desktop by running the following command:
gsettings set org.gnome.desktop.peripherals.touchpad send-events enabled
