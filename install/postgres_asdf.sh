#!/usr/bin/env bash

asdf plugin-add postgres https://github.com/smashedtoatoms/asdf-postgres.git

$postgres_version=$1

if [ -z "$postgres_version"]
then
  $postgres_version=$(asdf list-all postgres)
fi

asdf install postgres $postgres_version
asdf global postgres $postgres_version
