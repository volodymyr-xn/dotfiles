#!/usr/bin/env bash

# Advanced Power Management for Linux
# https://github.com/linrunner/TLP

sudo add-apt-repository ppa:linrunner/tlp

yes | sudo apt install tlp tlp-rdw

# ThinkPad only
# sudo apt install acpi-call-dkms tp-smapi-dkms

# External kernel module providing battery charge thresholds
# and recalibration for newer ThinkPads (X220/T420 and later)
# acpi-call-dkms (universe) – optional

# External kernel module providing battery charge thresholds,
# recalibration and specific tlp-stat -b output for older ThinkPads
# tp-smapi-dkms (PPA or universe) – optional
