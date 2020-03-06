#!/usr/bin/env bash

asdf plugin-add ruby https://github.com/asdf-vm/asdf-ruby.git

ruby_version=${1:-2.6.5}

RUBY_CONFIGURE_OPTS=--with-jemalloc asdf install ruby $ruby_version


asdf global ruby $ruby_version
asdf reshim ruby

echo "\nBuilt with libs:"
ruby -r rbconfig -e "puts RbConfig::CONFIG['MAINLIBS']"
