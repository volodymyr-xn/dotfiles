#!/usr/bin/env bash

echo "Using wineprefix: $WINEPREFIX"

# For export "vcrun2015" is required

rum ElementalWarrior-8.14 $HOME/WinePrefixes/wineAffinityExperimental winetricks \
  vcrun2015 \
  fontsmooth=rgb \
  atmlib \
  msxml3 \
  msxml6 \
  gdiplus \
  vcrun2010 \
  vcrun2012 \
  vcrun2013 \
  d3dx9 \
  d3dx10 \
  d3dx11_42 \
  d3dx11_43 \
  dxvk
  # allfonts \
  # corefonts \
#   fontsmooth-rgb \

