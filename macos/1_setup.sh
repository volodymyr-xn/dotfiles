#!/usr/bin/env bash

set -euo pipefail

DOTFILES_DIR="$HOME/dotfiles"

# Install Homebrew if missing
if ! command -v brew >/dev/null 2>&1; then
  echo "▶ Installing Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

echo "▶ Installing packages from Brewfile"
brew bundle --file "$DOTFILES_DIR/macos/Brewfile"

echo "▶ Applying macOS defaults"
bash "$DOTFILES_DIR/macos/defaults.sh"
