#!/usr/bin/env bash

# cd /tmp
# Check if those steps needed
sudo mkdir /var/lib/pgadmin
sudo mkdir /var/log/pgadmin
sudo chown $USER /var/lib/pgadmin
sudo chown $USER /var/log/pgadmin
# python3 -m venv pgadmin4
# source pgadmin4/bin/activate

# Install with
pip install pgadmin4

# Pgadmin4 webapp database stored in
# /var/lib/pgadmin/pgadmin4.db

# Update with
# pip install pgadmin4 -U
