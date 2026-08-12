#!/usr/bin/env bash

set -euo pipefail

DOTFILES_DIR="$HOME/dotfiles"

# Run every Linux-specific setup script in this directory (skip self)
self="$(basename "${BASH_SOURCE[0]}")"

for script in "$DOTFILES_DIR"/linux/*.sh; do
  [ -e "$script" ] || continue
  [ "$(basename "$script")" = "$self" ] && continue
  echo "▶ Running $(basename "$script")"
  bash "$script"
done
