#!/usr/bin/env bash

cd $HOME/dotfiles/install

./brotli_from_homebrew.sh
# ./brotli_from_apt.sh
./go.sh
./h2o_from_source.sh
./virtualbox.sh
./vips_from_homebrew.sh
# ./vips_from_source.sh

# ./faktory.sh
# ./gotop.sh
