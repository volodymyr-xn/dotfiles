#!/usr/bin/env bash

yes | sudo apt install flatpak gnome-software-plugin-flatpak

flatpak remote-add \
  --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
