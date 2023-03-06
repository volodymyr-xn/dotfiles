#!/usr/bin/env bash

asdf plugin-add ruby https://github.com/asdf-vm/asdf-ruby.git

ruby_version=$1

if [ -z "$ruby_version"]
then
  ruby_version="latest"
fi

RUBY_CONFIGURE_OPTS="--with-jemalloc --enable-yjit" asdf install ruby "$ruby_version"


asdf global ruby latest
asdf reshim ruby

echo "\nRuby built with libs:"
ruby -r rbconfig -e "puts RbConfig::CONFIG['MAINLIBS']"
