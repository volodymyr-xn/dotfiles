#!/usr/bin/env bash

ssh-keygen  -t rsa -b 4096 -C "volodymyr.shevchuk93@gmail.com"

ssh-add ~/.ssh/id_rsa
