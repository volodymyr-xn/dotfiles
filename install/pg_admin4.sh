#!/usr/bin/env bash

cd /tmp
wget https://ftp.postgresql.org/pub/pgadmin/pgadmin4/v7.3/source/pgadmin4-7.3.tar.gz

sudo mkdir /var/lib/pgadmin
sudo mkdir /var/log/pgadmin
sudo chown $USER /var/lib/pgadmin
sudo chown $USER /var/log/pgadmin
python3 -m venv pgadmin4
source pgadmin4/bin/activate
pip install pgadmin4
