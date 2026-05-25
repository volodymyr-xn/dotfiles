#!/usr/bin/env bash

set -u

########## Keybindings ##########

# Schema shortcuts
media_keys_keybinding_schema=/org/gnome/settings-daemon/plugins/media-keys

# Screen lock
# Ctrl-Alt-l
dconf write $media_keys_keybinding_schema/screensaver "['<Primary><Alt>l']"

# Close application window
# Alt-q
dconf write /org/gnome/desktop/wm/keybindings/close "['<Alt>q']"

# Hide application window
# Alt-w
# dconf write /org/gnome/desktop/wm/keybindings/minimize "['<Alt>w']"

# Hide all windows
# Alt-a
# dconf write /org/gnome/desktop/wm/keybindings/show-desktop "['<Alt>a']"

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
dconf write $media_keys_keybinding_schema/previous "['KP_1']"

# Next track
# 2 on numpad
dconf write $media_keys_keybinding_schema/next "['KP_2']"

# Make screenshot of area and save to pictures
# F3
dconf write $media_keys_keybinding_schema/area-screenshot "['F3']"

# Make screenshot of area and copy to clipboard
# F2
dconf write $media_keys_keybinding_schema/area-screenshot-clip "['F2']"


# Disable screenshot button
dconf write $media_keys_keybinding_schema/screenshot "@as []"

# TODO mapping for Insert button

# Start terminal
# 3 on numpad
dconf write /org/gnome/settings-daemon/plugins/media-keys/terminal \
  "['KP_Next']"

# Run media player
# Disabled
# 4 on numpad
# dconf write $media_keys_keybinding_schema/media "['KP_Left']"

# Toggle terminal fullscreen
# 5 on numpad
dconf write \
    /org/gnome/desktop/wm/keybindings/toggle-fullscreen \
    "['KP_Begin']"


# Disabled
# dconf write \
#   /apps/guake/keybindings/global/show-hide \
#   "'<Alt>j'"

# Change this after Gnome 40 update
# Move to workspace up
dconf write \
  /org/gnome/desktop/wm/keybindings/switch-to-workspace-up \
  "['<Alt>Up']"

# Change this after Gnome 40 update
# Move to workspace down
dconf write \
  /org/gnome/desktop/wm/keybindings/switch-to-workspace-down \
  "['<Alt>Down']"

# Switch between workspaces
# Alt+num(1-4)
dconf write \
  /org/gnome/desktop/wm/keybindings/switch-to-workspace-1 \
  "['<Alt>1']"

dconf write \
  /org/gnome/desktop/wm/keybindings/switch-to-workspace-2 \
  "['<Alt>2']"

dconf write \
  /org/gnome/desktop/wm/keybindings/switch-to-workspace-3 \
  "['<Alt>3']"

dconf write \
  /org/gnome/desktop/wm/keybindings/switch-to-workspace-4 \
  "['<Alt>4']"

########## Custom keybindings ##########

# Schema shortcuts
custom_keybinding_schema=$media_keys_keybinding_schema/custom-keybindings

# Toggle display focus keybinding
# Ctrl+Space
toggle_display_focus_keybinding_schema=$custom_keybinding_schema/custom0

dconf write \
  $toggle_display_focus_keybinding_schema/name \
  "'Toggle display focus'"

dconf write \
  $toggle_display_focus_keybinding_schema/command \
  "'toggle-display-focus'"

dconf write \
  $toggle_display_focus_keybinding_schema/binding \
  "'<Control>space'"


# Run universal Rofi launcher keybinding
universal_rofi_keybinding_schema=$custom_keybinding_schema/custom1

# dconf write \
#   $universal_rofi_keybinding_schema/name \
#   "'Rofi'"
#
# dconf write \
#   $universal_rofi_keybinding_schema/command \
#   "'rofi -combi-modi window,drun -show combi -modi combi'"
#
# # Ctrl+Shift+p
# dconf write \
#   $universal_rofi_keybinding_schema/binding \
#   "'<Primary><Shift>p'"
dconf write \
  $universal_rofi_keybinding_schema/name \
  "'Notes searcher'"

dconf write \
  $universal_rofi_keybinding_schema/command \
  "'xen-searcher'"

# Command runner
# Alt+i
dconf write \
  $universal_rofi_keybinding_schema/binding \
  "'<Alt>i'"

launch_kitty=$custom_keybinding_schema/custom2

dconf write \
  $launch_kitty/name \
  "'Launch Kitty'"

dconf write \
  $launch_kitty/command \
    "'kitty'"

dconf write \
  $launch_kitty/binding \
  "'<Primary><Alt>t'"

moria_open=$custom_keybinding_schema/custom3

dconf write \
  $moria_open/name \
  "'Notes open'"

dconf write \
  $moria_open/command \
  "'xen-open'"

# # Ctrl+Shift+p
dconf write \
  $moria_open/binding \
  "'<Alt>o'"

##### Suspend system
suspend_system=$custom_keybinding_schema/custom4

dconf write \
  $suspend_system/name \
  "'Suspend system'"

dconf write \
  $suspend_system/command \
  "'systemctl suspend'"

# # Ctrl+Alt+k
dconf write \
  $suspend_system/binding \
  "'<Primary><Alt>k'"

##### Shutdown system
shutdown_system=$custom_keybinding_schema/custom5

dconf write \
  $shutdown_system/name \
  "'Shutdown system'"

dconf write \
  $shutdown_system/command \
  "'systemctl poweroff -i'"

# Ctrl+Alt+n
dconf write \
  $shutdown_system/binding \
  "'<Primary><Alt>n'"

# Decrease monitor brihgtness shortcut
# Numpad7
decrease_monitor_brightness=$custom_keybinding_schema/custom10

dconf write \
  $decrease_monitor_brightness/name \
  "'Decrease monitor brihgtness'"

dconf write \
  $decrease_monitor_brightness/command \
  "'c-decrease-monitor-brightness'"

dconf write \
  $decrease_monitor_brightness/binding \
  "'F3'"

# Increase monitor brihgtness shortcut
# Numpad8
increase_monitor_brightness=$custom_keybinding_schema/custom11
dconf write \
  $increase_monitor_brightness/name \
  "'Increase monitor brihgtness'"

dconf write \
  $increase_monitor_brightness/command \
  "'c-increase-monitor-brightness'"

dconf write \
  $increase_monitor_brightness/binding \
  "'F4'"

hide_dock_keybind_schema=$custom_keybinding_schema/custom12

dconf write \
  $hide_dock_keybind_schema/name \
  "'Hide dock'"

dconf write \
  $hide_dock_keybind_schema/command \
  "'c-toggle-dock-mode'"

dconf write \
  $hide_dock_keybind_schema/binding \
  "'F8'"


# # Launch todo shortcut
# # Alt+l
# launch_todo=$custom_keybinding_schema/custom6
#
# dconf write \
#   $launch_todo/name \
#   "'Launch todo'"
#
# dconf write \
#   $launch_todo/command \
#   "'trello-todo'"
#
# dconf write \
#   $launch_todo/binding \
#   "'<Primary><Alt>p'"

# Launch command runner shortcut
# display_command_runner=$custom_keybinding_schema/custom7

# dconf write \
#   $display_command_runner/name \
#   "'Display command runner'"

# dconf write \
#   $display_command_runner/binding \
#   "'<Alt>p'"

# Launch command runner shortcut
# display_moria_command_runner=$custom_keybinding_schema/custom8

# dconf write \
#   $display_moria_command_runner/name \
#   "'Display Moria command runner menu'"

# dconf write \
#   $display_moria_command_runner/command \
#   "'moria-command-runner'"

# dconf write \
#   $display_moria_command_runner/binding \
#   "'<Alt>m'"

# Make screenshot of the window into dir
make_active_app_window_screenshot_keybinding=$custom_keybinding_schema/custom9

# dconf write \
#   $make_active_app_window_screenshot_keybinding/name \
#   "'Make screenshot of the window into dir'"
#
# dconf write \
#   $make_active_app_window_screenshot_keybinding/command \
#   "'make-active-app-window-screenshot'"
#
# dconf write \
#   $make_active_app_window_screenshot_keybinding/binding \
#   "'F4'"


# Make screenshot of the window into dir and edit
make_active_app_window_screenthot_and_edit_keybinding=$custom_keybinding_schema/custom10

# dconf write \
#   $make_active_app_window_screenthot_and_edit_keybinding/name \
#   "'Make screenshot of the window into dir and edit'"
#
# dconf write \
#   $make_active_app_window_screenthot_and_edit_keybinding/command \
#   "'make-active-window-app-screenshot-and-edit'"
#
# dconf write \
#   $make_active_app_window_screenthot_and_edit_keybinding/binding \
#   "'F5'"
#

# Define list of all keybindings
# Should be carefull here. It could broke the gnome
dconf write \
  $custom_keybinding_schema \
  "['$toggle_display_focus_keybinding_schema/', '$universal_rofi_keybinding_schema/', '$launch_kitty/', '$moria_open/', '$suspend_system/','$shutdown_system/', '$decrease_monitor_brightness/', '$increase_monitor_brightness/', '$display_command_runner/', '$display_moria_command_runner/', '$make_active_app_window_screenshot_keybinding/', '$make_active_app_window_screenthot_and_edit_keybinding/']"
