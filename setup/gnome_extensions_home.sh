#!/usr/bin/env bash

dconf write \
  /org/gnome/shell/enabled-extensions \
  "[ 'user-theme@gnome-shell-extensions.gcampax.github.com', 'workspace-indicator@gnome-shell-extensions.gcampax.github.com', 'auto-move-windows@gnome-shell-extensions.gcampax.github.com']"

dconf write \
  /org/gnome/desktop/wm/preferences/num-workspaces \
  4

dconf write \
  /org/gnome/mutter/dynamic-workspaces \
  true

