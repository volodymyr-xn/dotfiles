redis_version=stable

cd /tmp
# 1. Download stable Redis sources
wget http://download.redis.io/redis-$redis_version.tar.gz
# 2. Unpack Redis sources
tar xzvf redis-$redis_version.tar.gz &>> /dev/null
# Go to the directory with Redis
cd redis-$redis_version
# 3. Make Redis
make &>> /dev/null
# 4. Install Redis into /usr/local
sudo make install prefix=/usr/local/bin &>> /dev/null
# 5. Additional setup for Redis-server
cd utils

warn 'Use default Redis settings'
echo yes | sudo ./install_server.sh
