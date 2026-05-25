#!/usr/bin/env bash

# Ensure baseline tools required by the rest of the setup scripts are present.
# Idempotent: each tool is only installed if missing.

set -euo pipefail

DOTFILES_DIR="$HOME/dotfiles"

log() { printf "\n▶ %s\n" "$*"; }

# Run a command only when the named binary is missing
ensure_command() {
  local cmd="$1"
  shift

  if command -v "$cmd" >/dev/null 2>&1; then
    echo "✓ $cmd already installed"
    return 0
  fi

  log "Installing $cmd"
  "$@"
}

install_xcode_clt() {
  if xcode-select -p >/dev/null 2>&1; then
    echo "✓ Xcode Command Line Tools already installed"
    return 0
  fi

  log "Installing Xcode Command Line Tools"
  xcode-select --install || true

  # Wait for user-driven install to finish before continuing
  until xcode-select -p >/dev/null 2>&1; do
    sleep 5
  done
}

install_homebrew() {
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}

install_oh_my_zsh() {
  if [ -d "$HOME/.oh-my-zsh" ]; then
    echo "✓ oh-my-zsh already installed"
    return 0
  fi

  log "Installing oh-my-zsh"
  RUNZSH=no CHSH=no \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
}

detect_linux_pm() {
  if command -v apt-get >/dev/null 2>&1; then echo "apt"
  elif command -v dnf >/dev/null 2>&1; then echo "dnf"
  elif command -v pacman >/dev/null 2>&1; then echo "pacman"
  else echo ""
  fi
}

linux_pm_install() {
  local pm="$1"
  shift

  case "$pm" in
    apt)    sudo apt-get update && sudo apt-get install -y "$@" ;;
    dnf)    sudo dnf install -y "$@" ;;
    pacman) sudo pacman -S --noconfirm "$@" ;;
    *)      echo "Unknown package manager: $pm" >&2; return 1 ;;
  esac
}

prepare_macos() {
  install_xcode_clt
  ensure_command brew install_homebrew

  # Modern git/zsh from brew; macOS ships outdated versions
  ensure_command git  brew install git
  ensure_command zsh  brew install zsh
  ensure_command curl brew install curl

  install_oh_my_zsh
}

prepare_linux() {
  local pm

  pm="$(detect_linux_pm)"

  if [ -z "$pm" ]; then
    echo "No supported package manager found (apt/dnf/pacman)" >&2
    exit 1
  fi

  ensure_command git  linux_pm_install "$pm" git
  ensure_command zsh  linux_pm_install "$pm" zsh
  ensure_command curl linux_pm_install "$pm" curl

  install_oh_my_zsh
}

case "$OSTYPE" in
  darwin*) prepare_macos ;;
  linux*)  prepare_linux ;;
  *)
    echo "Unsupported OSTYPE: $OSTYPE" >&2
    exit 1
    ;;
esac

log "All baseline tools ready"
