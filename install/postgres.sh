#!/usr/bin/env bash

wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
# sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ bionic-pgdg main" > /etc/apt/sources.list.d/pgdg_bionic.list'
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lbs_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg_xenial.list'

sudo apt update
sudo apt-get install postgresql-12
