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
gsettings set org.gnome.desktop.input-sources xkb-options "['caps:none', 'grp:alt_shift_toggle']"

# Gnome terminal settings
gnome_terminal=$(gsettings get org.gnome.Terminal.ProfilesList default)
gnome_terminal=${gnome_terminal:1:-1} # remove leading and trailing single quotes
gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$gnome_terminal/" font "Fira Mono Medium 14"

# gconftool-2 set /apps/metacity/general/focus_new_windows --type string strict

# Keybindings
# Toggle display focus
media_keys_keybinding_schema=/org/gnome/settings-daemon/plugins/media-keys
custom_keybinding_schema=$media_keys_keybinding_schema/custom-keybindings

custom_keybinding_0_schema=$custom_keybinding_schema/custom0
dconf write $custom_keybinding_0_schema/name "'Toggle display focus'"
dconf write $custom_keybinding_0_schema/command "'toggle-display-focus'"
dconf write $custom_keybinding_0_schema/binding "'<Control>space'"

# zero on numpad
dconf write $media_keys_keybinding_schema/play/command "'KP_Insert'"

# minus on numpad
dconf write $media_keys_keybinding_schema/volume-down/command "'KP_Subtract'"

# plus on numpad
dconf write $media_keys_keybinding_schema/volume-up/command "'KP_Add'"

# 1 on numpad
dconf write $media_keys_keybinding_schema/previous/command "'KP_End'"

# 2 on numpad
dconf write $media_keys_keybinding_schema/next/command "'KP_Down'"

# Make screenshot of area
dconf write $media_keys_keybinding_schema/area-screenshot-clip "'F2'"

# Run media player
dconf write $media_keys_keybinding_schema/media "'KP_Begin'"

# Rofi setup
custom_keybinding_1_schema=$custom_keybinding_schema/custom1
dconf write $custom_keybinding_1_schema/name "'Rofi'"
dconf write $custom_keybinding_1_schema/command "'rofi -combi-modi window,drun -show combi -modi combi'"

dconf write $custom_keybinding_1_schema/binding "'<Primary><Shift>p'"

# Should be carefull here. It could broke the gnome
# dconf write $custom_keybinding_schema "['$custom_keybinding_0_schema/', '$custom_keybinding_1_schema/']"
