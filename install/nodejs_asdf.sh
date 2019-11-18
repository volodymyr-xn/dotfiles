#!/usr/bin/env bash

asdf plugin-add nodejs https://github.com/asdf-vm/asdf-nodejs.git

bash ~/.asdf/plugins/nodejs/bin/import-release-team-keyring

node_version=${1:-12.13.0}

asdf install nodejs $node_version
asdf global nodejs $node_version

# Install yarn globally
npm i yarn -g

# Install eslint globally
npm i eslint -g

# Install eslint globally
npm i stylelint -g

# Install stylelint globally
npm install stylelint-config-standard -g
