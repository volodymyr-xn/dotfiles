#!/usr/bin/env bash

asdf plugin-add nodejs https://github.com/asdf-vm/asdf-nodejs.git

bash ~/.asdf/plugins/nodejs/bin/import-release-team-keyring

asdf install nodejs $1
asdf global nodejs $l1

# Install yarn globally
npm i yarn -g

# Install eslint globally
npm i eslint -g

# Install eslint globally
npm i stylelint -g

# Install stylelint globally
npm install stylelint-config-standard -g
