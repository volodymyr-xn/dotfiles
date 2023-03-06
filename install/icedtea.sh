#!/usr/bin/env bash
#
# # Install Open JDK Java first
# https://linuxize.com/post/install-java-on-ubuntu-18-04/
#
# sudo add-apt-repository ppa:maarten-fonville/ppa
# sudo apt-get update
# sudo apt-get install icedtea-8-plugin
#
# # mkdir -p ~/.mozilla/plugins
# # rm ~/.mozilla/plugins/libnpjp2.so
# # ln -s /usr/lib/jvm/java-9-oracle/lib/libnpjp2.so ~/.mozilla/plugins/
#
# For arch
# Maybe import to install java-runtime-openjdk (jre17-openjdk or newer)
# yay -S java-runtime-openjdk
yay -S icedtea-web
