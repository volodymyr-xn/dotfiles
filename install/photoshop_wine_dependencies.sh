#!/usr/bin/env bash

# winetricks fontsmooth=rgb gdiplus \
#   vcrun2008 vcrun2010  \
#   vcrun2012 vcrun2013 vcrun2015 \
#   atmlib msxml4 msxml6 gdiplus \
#   corefonts mfc40 mfc42

# from habr
winetricks fontsmooth=rgb allfonts corefonts vcrun2008 vcrun2010 gdiplus vcrun2012 vcrun2013 vcrun2015 atmlib msxml3 msxml6 d3dx9 d3dx10 d3dx11_42 d3dx11_43 dxvk vulkanrt
