#!/usr/bin/env bash

asdf plugin-add java https://github.com/halcyon/asdf-java.git

java_version=$1

if [ -z "$java_version"]
then
  java_version="latest"
fi

asdf install java "$java_version"

asdf global java latest
asdf reshim java
