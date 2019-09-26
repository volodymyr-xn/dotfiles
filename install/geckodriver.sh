#!/usr/bin/env bash

version=v0.23.0

cd /tmp && wget https://github.com/mozilla/geckodriver/releases/download/$version/geckodriver-$version-linux64.tar.gz
sudo tar -xvzf geckodriver-$version-linux64.tar.gz -C /usr/local/bin
rm -f geckodriver-$version-linux64.tar.gz
