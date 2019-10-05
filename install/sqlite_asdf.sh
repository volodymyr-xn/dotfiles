#!/usr/bin/env bash

asdf plugin-add sqlite https://github.com/cLupus/asdf-sqlite.git

asdf install sqlite $1
asdf global sqlite $1
