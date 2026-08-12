#!/usr/bin/env bash

set -euo pipefail

DOTFILES_DIR="$HOME/dotfiles"

# Dispatch to the platform-specific setup entry point
case "$OSTYPE" in
  darwin*)
    bash "$DOTFILES_DIR/macos/1_setup.sh"
    ;;
  linux*)
    bash "$DOTFILES_DIR/linux/1_setup.sh"
    ;;
  *)
    echo "Unsupported OSTYPE: $OSTYPE" >&2
    exit 1
    ;;
esac
