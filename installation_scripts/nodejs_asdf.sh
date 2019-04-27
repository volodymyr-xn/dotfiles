#!/usr/bin/env bash

asdf plugin-add nodejs https://github.com/asdf-vm/asdf-nodejs.git

bash ~/.asdf/plugins/nodejs/bin/import-release-team-keyring

last_node_version=10.15.3
asdf install nodejs $last_node_version
asdf global nodejs $last_node_version

# Install yarn globally
npm i yarn -g
