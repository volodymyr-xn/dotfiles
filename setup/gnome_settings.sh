#!/usr/bin/env bash

##### Gnome settings #####

# Disable Caps Lock
# Alt+Shift - language swtich
dconf write \
  /org/gnome/desktop/input-sources/xkb-options \
  "['caps:none', 'grp:alt_shift_toggle']"

# Theme
dconf write /org/gnome/desktop/wm/preferences/theme "'Adwaita-dark'"
dconf write /org/gnome/desktop/interface/gtk-theme "'Adwaita-dark'"

# Icon theme
dconf write /org/gnome/desktop/interface/icon-theme "'Numix-Circle'"

# Curson theme
dconf write /org/gnome/desktop/interface/cursor-theme "'DMZ-Black'"

# Set gnome shell theme
# gsettings set org.gnome.shell.extensions user-theme 'Arc-Dark'

# Gnome terminal settings
gnome_terminal=$(gsettings get org.gnome.Terminal.ProfilesList default)
gnome_terminal=${gnome_terminal:1:-1} # remove leading and trailing single quotes
gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$gnome_terminal/" font "Monego Regular 14"

# Set default monospace font
dconf write /org/gnome/desktop/interface/monospace-font-name "'Monego Bold 14'"
