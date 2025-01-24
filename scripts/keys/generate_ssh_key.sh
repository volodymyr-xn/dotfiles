#!/usr/bin/env bash

ssh-keygen  -t rsa -b 4096 -C "volodymyr.shevchuk.dev@gmail.com"

ssh-add ~/.ssh/id_rsa
