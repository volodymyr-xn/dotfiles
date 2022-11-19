#!/usr/bin/env bash

#  winetricks fontsmooth=rgb gdiplus \
  # allfonts corefonts \
  # vcrun2005 vcrun2008 vcrun2010 vcrun2012 vcrun2013 vcrun2015  \
  # atmlib  \
  # msxml3 msxml4 msxml6 \
  # gdiplus \
  # vcrun6 \
  # mfc40 mfc42 \
  # wsh57 \
  # msvcirt dxvk vulkanrt dinput8 directplay \
  # d3dx9 d3dx10 d3dx11_42 d3dx11_43 d3dcompiler_43
  # dxvk vulkanrt
  # dotnet20


# from habr
# WINEPREFIX=/home/tech/StandaloneApps/Photoshop/Wine/WinePrefixes/wine-experiment winetricks fontsmooth=rgb allfonts corefonts vcrun2008 vcrun2010 gdiplus \
#   vcrun2012 vcrun2013 vcrun2015 atmlib msxml3 msxml6 \
#   vb6run vcrun6 vcrun2005 mfc40 mfc42

WINEPREFIX=/media/tech/Files-SSD-2TB/Games/WindowsInstalled/Wine-6 winetricks \
  fontsmooth=rgb \
  allfonts \
  corefonts \
  gdiplus \
  vcrun2012 \
  vcrun2013 \
  vcrun2015 \
  atmlib \
  msxml3 \
  msxml6 \
  d3dx9 \
  d3dx10 \
  d3dx11_42 \
  d3dx11_43 \
  ie6\
  fontsmooth-rgb \
  gecko \
  # dxvk \
  # vulkanrt \
# WINEPREFIX=/home/tech/StandaloneApps/Photoshop/Wine/WinePrefixes/wine-experiment winetricks atmlib \
#   fontsmooth=rgb vcrun2008 vcrun2010 vcrun2012 vcrun2013 \
#   atmlib msxml3 msxml6
