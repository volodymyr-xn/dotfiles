#!/usr/bin/env bash

# sudo add-apt-repository ppa:maarten-fonville/ppa
# sudo apt-get update
# sudo apt-get install icedtea-8-plugin

mkdir -p ~/.mozilla/plugins
rm ~/.mozilla/plugins/libnpjp2.so
ln -s /usr/lib/jvm/java-9-oracle/lib/libnpjp2.so ~/.mozilla/plugins/
