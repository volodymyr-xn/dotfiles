#!/usr/bin/env bash

# Theme
gsettings set org.gnome.desktop.wm.preferences theme 'Arc-Darker'
gsettings set org.gnome.desktop.interface gtk-theme 'Arc-Darker'

# Icon theme
gsettings set org.gnome.desktop.interface icon-theme 'Numix-Circle'

# Curson theme
gsettings set org.gnome.desktop.interface cursor-theme 'DMZ-Black'

# Set gnome shell theme
# gsettings set org.gnome.shell.extensions user-theme 'Arc-Dark'

# Disable Caps Lock
# dconf write /org/gnome/desktop/input-sources/xkb-options "['caps:none']"
gsettings set org.gnome.desktop.input-sources xkb-options "['caps:none']"

# Gnome terminal settings
gnome_terminal=$(gsettings get org.gnome.Terminal.ProfilesList default)
gnome_terminal=${gnome_terminal:1:-1} # remove leading and trailing single quotes
gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$gnome_terminal/" font "Fira Mono Medium 14"

# gconftool-2 set /apps/metacity/general/focus_new_windows --type string strict

# Keybindings
# Toggle display focus
custom_keybinding_0_schema=/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0
dconf write $custom_keybinding_0_schema/name "'Toggle display focus'"
dconf write $custom_keybinding_0_schema/command "'toggle-display-focus'"
dconf write $custom_keybinding_0_schema/binding "'<Control>space'"

# Rofi setup
custom_keybinding_1_schema=/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1
dconf write $custom_keybinding_1_schema/name "'Rofi'"
dconf write $custom_keybinding_1_schema/command "'rofi -combi-modi \"window,drun\" -show combi'"
dconf write $custom_keybinding_1_schema/binding "'<Primary><Shift>f'"
