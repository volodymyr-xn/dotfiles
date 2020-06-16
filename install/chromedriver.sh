#!/usr/bin/env bash

version=83.0.4103.39

cd /tmp && wget https://chromedriver.storage.googleapis.com/$version/chromedriver_linux64.zip
sudo unzip chromedriver_linux64.zip -d /usr/local/bin
rm -f chromedriver_linux64.zip
