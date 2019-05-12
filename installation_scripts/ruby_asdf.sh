#!/usr/bin/env bash

asdf plugin-add ruby https://github.com/asdf-vm/asdf-ruby.git

RUBY_CONFIGURE_OPTS=--with-jemalloc asdf install ruby $1

ruby_version=$1

asdf global ruby $ruby_version

asdf reshim ruby
