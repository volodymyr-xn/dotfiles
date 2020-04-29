#!/usr/bin/env bash

# Advanced Power Management for Linux
# https://github.com/linrunner/TLP

sudo add-apt-repository ppa:linrunner/tlp

yes | sudo apt install tlp tlp-rdw # x86_energy_perf_policy
