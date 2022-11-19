#!/usr/bin/env bash

wget -qO - https://packages.lunarg.com/lunarg-signing-key-pub.asc | sudo apt-key add -

sudo wget -qO /etc/apt/sources.list.d/lunarg-vulkan-1.2.162-focal.list https://packages.lunarg.com/vulkan/1.2.162/lunarg-vulkan-1.2.162-focal.list

sudo apt update
sudo apt install vulkan-sdk
