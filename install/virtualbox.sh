#!/usr/bin/env bash

yes | wget -q https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- | sudo apt-key add -
yes | sudo add-apt-repository "deb [arch=amd64] http://download.virtualbox.org/virtualbox/debian bionic contrib"
yes | sudo apt-get update && sudo apt-get install virtualbox-6.0
