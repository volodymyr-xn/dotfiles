#!/usr/bin/env bash

asdf plugin-add ruby https://github.com/asdf-vm/asdf-ruby.git

source ~/dotfiles/packages_versions.sh

last_ruby_version=$ruby_version

echo "Install ruby $last_ruby_version"
asdf install ruby $last_ruby_version
asdf global ruby $last_ruby_version

asdf reshim ruby
