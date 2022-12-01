#!/usr/bin/env bash

asdf plugin-add nodejs https://github.com/asdf-vm/asdf-nodejs.git

bash ~/.asdf/plugins/nodejs/bin/import-release-team-keyring

# node_version=${1:-12.13.0}
node_version=$1

if [ -z "$node_version"]
then
  regular_nodejs_version_regexp='^[0-9]\.[0-9]\.[0-9]'

  # node_version=$(asdf list-all ruby | egrep "$regular_nodejs_version_regexp" | tail -n 1)
  node_version="lts"
fi

asdf install nodejs "$node_version"
asdf global nodejs "$node_version"

# Install yarn globally
npm i yarn -g

# Install eslint globally
npm i eslint -g

# Install eslint globally
# npm i stylelint -g

# Install stylelint globally
# npm install stylelint-config-standard -g
