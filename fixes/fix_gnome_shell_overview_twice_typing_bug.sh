#!/usr/bin/env bash

# This fixes error on Gnome shell overview mode when first letter typed twice
dconf write /org/gnome/shell/extensions/dash-to-dock/disable-overview-on-startup true
