#!/usr/bin/env bash

yes | sh -c "$(curl -fsSL https://raw.githubusercontent.com/Linuxbrew/install/master/install.sh)"

source .profile

brew analytics off
