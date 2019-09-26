#!/usr/bin/env bash

#Install required packages to allow apt to use a repository over HTTPS
yes | sudo apt-get install \
  apt-transport-https \
  ca-certificates \
  curl \
  software-properties-common


# Add Docker’s official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -


# Verification for gpg key
sudo apt-key fingerprint 0EBFCD88


# Add docker stable respository for ubuntu
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

# Update apt package index
sudo apt-get update

# Install Docker CE
sudo apt-get install docker-ce

# Verify docker installation by running docker test image
sudo docker run hello-world
