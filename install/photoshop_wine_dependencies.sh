#!/usr/bin/env bash

winetricks \
  fontsmooth=rgb gdiplus vcrun2008 vcrun2010 \
  vcrun2012 vcrun2013 vcrun2015 atmlib \
  msxml3 msxml6 gdiplus corefonts mfc42
