#!/usr/bin/env bash

version=2.44

cd /tmp && wget https://chromedriver.storage.googleapis.com/$version/chromedriver_linux64.zip
sudo unzip chromedriver_linux64.zip -d /usr/local/bin
rm -f chromedriver_linux64.zip
