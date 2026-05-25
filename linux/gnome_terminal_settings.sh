#!/usr/bin/env bash

#============ Gnome terminal settings ==========================================
# Change Gnome terminal font
gnome_terminal=$(gsettings get org.gnome.Terminal.ProfilesList default)
gnome_terminal=${gnome_terminal:1:-1} # remove leading and trailing single quotes
# terminal_font="Monego Bold 14"
terminal_font="MesloLGM Nerd Font Bold 14"
# terminal_font="Monaco Nerd Font Bold 12"
# terminal_font="Fira Mono Medium 14"

gnome_terminal_profile_full_path="org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$gnome_terminal/"

gsettings set "$gnome_terminal_profile_full_path" font "$terminal_font"
gsettings set "$gnome_terminal_profile_full_path" scrollbar-policy 'never'

