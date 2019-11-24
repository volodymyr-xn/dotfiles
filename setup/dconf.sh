#!/usr/bin/env bash

# language swtich
dconf write /org/gnome/desktop/input-sources/xkb-options "['grp:alt_shift_toggle']"


# Theme
dconf write /org/gnome/desktop/wm/preferences/theme "'Adwaita Dark'"
dconf write /org/gnome/desktop/interface/gtk-theme "'Adwaita dark'"

# Icon theme
dconf write /org/gnome/desktop/interface/icon-theme "'Numix-Circle'"

# Curson theme
dconf write /org/gnome/desktop/interface/cursor-theme "'DMZ-Black'"

# Set gnome shell theme
# gsettings set org.gnome.shell.extensions user-theme 'Arc-Dark'

# Disable Caps Lock
dconf write /org/gnome/desktop/input-sources/xkb-options "['caps:none']"

# Gnome terminal settings
gnome_terminal=$(gsettings get org.gnome.Terminal.ProfilesList default)
gnome_terminal=${gnome_terminal:1:-1} # remove leading and trailing single quotes
gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$gnome_terminal/" font "Monaco Regular 14"

### Gnome settings ###
# Set default monospace font
dconf write /org/gnome/desktop/interface/monospace-font-name "'Monaco Regular 14'"

########## Keybindings ##########

# Schema shortcuts
media_keys_keybinding_schema=/org/gnome/settings-daemon/plugins/media-keys

# Play sound
# zero on numpad
dconf write $media_keys_keybinding_schema/play "['KP_Insert']"

# Volume down
# minus on numpad
dconf write $media_keys_keybinding_schema/volume-down "['KP_Subtract']"

# Volume up
# plus on numpad
dconf write $media_keys_keybinding_schema/volume-up "['KP_Add']"

# Mute sound
# * on numpad
dconf write $media_keys_keybinding_schema/volume-mute "['KP_Multiply']"

# Previous track
# 1 on numpad
dconf write $media_keys_keybinding_schema/previous "['KP_End']"

# Next track
# 2 on numpad
dconf write $media_keys_keybinding_schema/next "['KP_2']"

# Make screenshot of area
# F2
dconf write $media_keys_keybinding_schema/area-screenshot-clip "['F2']"

# Run media player
# 4 on numpad
dconf write $media_keys_keybinding_schema/media "['KP_Left']"

# Toggle terminal fullscreen
# 4 on numpad
dconf write /org/gnome/terminal/legacy/keybindings/full-screen "['KP_Begin']"

########## Custom keybindings ##########

# Schema shortcuts
custom_keybinding_schema=$media_keys_keybinding_schema/custom-keybindings

# Toggle display focus keybinding
toggle_display_focus_keybinding_schema=$custom_keybinding_schema/custom0
dconf write $toggle_display_focus_keybinding_schema/name "'Toggle display focus'"
dconf write $toggle_display_focus_keybinding_schema/command "'toggle-display-focus'"
dconf write $toggle_display_focus_keybinding_schema/binding "'<Control>space'"

# Run universal Rofi launcher keybinding
universal_rofi_keybinding_schema=$custom_keybinding_schema/custom1
dconf write $universal_rofi_keybinding_schema/name "'Rofi'"
dconf write $universal_rofi_keybinding_schema/command "'rofi -combi-modi window,drun -show combi -modi combi'"

# Ctrl+Shift+p
dconf write $universal_rofi_keybinding_schema/binding "'<Primary><Shift>p'"

# Define list of all keybindings
# Should be carefull here. It could broke the gnome
dconf write $custom_keybinding_schema "['$toggle_display_focus_keybinding_schema/', '$universal_rofi_keybinding_schema/']"
