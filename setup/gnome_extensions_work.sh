#!/usr/bin/env bash

### Gnome extensions ###
### List of enabled extensions
dconf write /org/gnome/shell/enabled-extensions \
  "['auto-move-windows@gnome-shell-extensions.gcampax.github.com']"

### Auto move windows extension config
dconf write /org/gnome/shell/extensions/auto-move-windows/application-list \
  "[ 'chromium_chromium.desktop:1', 'alacritty.desktop:2', 'slack_slack.desktop:3', 'firefox.desktop:4']"

dconf write \
  /org/gnome/desktop/wm/preferences/num-workspaces \
  4

dconf write \
  /org/gnome/mutter/dynamic-workspaces \
  true
