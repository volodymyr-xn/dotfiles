#!/usr/bin/env bash

redis_version=stable

cd /tmp

# Download stable Redis sources
wget http://download.redis.io/redis-$redis_version.tar.gz

# Unpack Redis sources
tar xzvf redis-$redis_version.tar.gz &>> /dev/null

# Go to the directory with Redis
cd redis-$redis_version

# Make Redis
make -j $(nproc)

# Install Redis into /usr/local
sudo make install prefix=/usr/local/bin &>> /dev/null

# Additional setup for Redis-server
cd utils

# Install Redis server
echo yes | sudo ./install_server.sh
