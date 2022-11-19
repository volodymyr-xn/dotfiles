#!/usr/bin/env bash

version=93.0.4577.63

cd /tmp
wget https://chromedriver.storage.googleapis.com/$version/chromedriver_linux64.zip
sudo unzip chromedriver_linux64.zip -d /usr/local/bin
rm -f chromedriver_linux64.zip
