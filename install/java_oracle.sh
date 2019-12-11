#!/usr/bin/env bash

# yes | sudo add-apt-repository ppa:webupd8team/java
# sudo apt-get update
# yes | sudo apt-get install oracle-java9-installer

yes | sudo add-apt-repository ppa:linuxuprising/java
yes | sudo apt install oracle-java11-installer-local
yes | sudo apt install oracle-java11-set-default-local
