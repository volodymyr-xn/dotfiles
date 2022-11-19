#!/usr/bin/env bash

cd $HOME/dotfiles/install

./imagemagic.sh
./jemalloc.sh

./ruby_asdf.sh
./nodejs_asdf.sh
./postgres_asdf.sh
./redis_asdf.sh
./crystal_asdf.sh

./universal-ctags.sh

./vips_from_homebrew.sh
# TODO: temporary not used
# ./geckodriver.sh
