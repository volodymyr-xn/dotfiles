#!/usr/bin/env bash

dconf write \
  /org/gnome/shell/enabled-extensions \
  ['user-theme@gnome-shell-extensions.gcampax.github.com', 'workspace-indicator@gnome-shell-extensions.gcampax.github.com', 'auto-move-windows@gnome-shell-extensions.gcampax.github.com', 'openweather-extension@jenslody.de', 'sound-output-device-chooser@kgshank.net', 'gsconnect@andyholmes.github.io']"

# dconf write \
  # /org/gnome/shell/extensions/sound-output-device-chooser/ports-settings \
  # \"'[{"human_name":"HDMI / DisplayPort","name":"hdmi-output-0","display_option":2},{"human_name":"HDMI / DisplayPort 2","name":"hdmi-output-1","display_option":2},{"human_name":"HDMI / DisplayPort 3","name":"hdmi-output-2","display_option":2},{"human_name":"HDMI / DisplayPort 4","name":"hdmi-output-3","display_option":2},{"human_name":"Front Microphone","name":"analog-input-front-mic","display_option":1},{"human_name":"Rear Microphone","name":"analog-input-rear-mic","display_option":1}]'\"


dconf write \
  /org/gnome/desktop/wm/preferences/num-workspaces \
  4

dconf write \
  /org/gnome/mutter/dynamic-workspaces \
  true
