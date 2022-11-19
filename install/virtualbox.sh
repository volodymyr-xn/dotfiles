#!/usr/bin/env bash

yes | wget -q https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- | sudo apt-key add -
yes | sudo add-apt-repository "deb [arch=amd64] http://download.virtualbox.org/virtualbox/debian focal contrib"
yes | sudo apt-get install virtualbox-6.1

# cd /tmp
# filename=virtualbox-6.1_6.1.18-142142~Ubuntu~eoan_amd64.deb
# wget https://download.virtualbox.org/virtualbox/6.1.18/$filename
# sudo dpkg -i $filename
# yes | sudo apt install virtualbox virtualbox-ext-pack
