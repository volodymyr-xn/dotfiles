#!/usr/bin/env bash

yes | sudo add-apt-repository ppa:webupd8team/java
sudo apt-get update
yes | sudo apt-get install oracle-java9-installer
