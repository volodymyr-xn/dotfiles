#!/usr/bin/env bash

asdf plugin-add postgres https://github.com/smashedtoatoms/asdf-postgres.git

postgres_version=$1

if [ -z "$postgres_version"]
then
  # if version is not specified take the latest postgres version
  postgres_version="latest"
fi

asdf install postgres $postgres_version
asdf global postgres $postgres_version
