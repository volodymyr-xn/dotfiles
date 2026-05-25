#!/usr/bin/env bash

dconf write \
  /org/gnome/shell/disable-user-extensions \
  false

# dconf write \
# /org/gnome/shell/enabled-extensions \
#   "['user-theme@gnome-shell-extensions.gcampax.github.com', 'workspace-indicator@gnome-shell-extensions.gcampax.github.com', 'auto-move-windows@gnome-shell-extensions.gcampax.github.com', 'openweather-extension@jenslody.de', 'sound-output-device-chooser@kgshank.net', 'gamemode@christian.kellner.me', 'blyr@yozoon.dev.gmail.com', 'desktop-icons@csoriano', 'dash-to-dock@micxgx.gmail.com', 'multi-volume@tigersoldier', 'impatience@gfxmonk.net', 'windowoverlay-icons@sustmidown.centrum.cz', 'gnome-vagrant-indicator@gnome-shell-exstensions.fffilo.github.com', 'topiconsfix@aleskva@devnullmail.com']"

### Auto move windows extension config
dconf write /org/gnome/shell/extensions/auto-move-windows/application-list \
  "['org.telegram.desktop.desktop:3', 'Alacritty.desktop:2']"

dconf write \
  /org/gnome/desktop/wm/preferences/num-workspaces \
  4

dconf write \
  /org/gnome/mutter/dynamic-workspaces \
  false
