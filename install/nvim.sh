#!/usr/bin/env bash

# Build and install Neovim from source on Ubuntu, Arch Linux, or macOS.
# Detects the OS, installs build deps via the native package manager,
# then compiles and installs to $HOME/.local (user-local, no sudo for install).

set -euo pipefail

# Install build-time dependencies for the detected OS.
install_deps() {
  local os="$1"

  case "$os" in
    macos)
      if ! command -v brew >/dev/null 2>&1; then
        echo "Homebrew is required on macOS. Install from https://brew.sh" >&2
        exit 1
      fi
      brew install ninja cmake gettext curl
      ;;
    arch)
      sudo pacman -S --needed --noconfirm \
        base-devel cmake ninja curl unzip \
        libuv libluv libtermkey libvterm luajit lua-lpeg lua-mpack \
        msgpack-c tree-sitter unibilium
      ;;
    ubuntu)
      sudo apt-get update
      sudo apt-get install -y \
        ninja-build gettext libtool libtool-bin autoconf automake \
        cmake g++ pkg-config unzip curl git
      ;;
    *)
      echo "Unsupported OS. Supported: macOS, Arch Linux, Ubuntu/Debian." >&2
      exit 1
      ;;
  esac
}

os="$(c-detect-os)"
echo "Detected OS: $os"

install_deps "$os"

neovim_source_dir="$(dotfiles-tempdir-for neovim)"

git clone https://github.com/neovim/neovim "$neovim_source_dir"
cd "$neovim_source_dir"

# Pin to the stable tag for reproducible installs; comment out for HEAD.
git checkout stable

echo "Starting compile process"
make clean || true
make \
  CMAKE_INSTALL_PREFIX="$HOME/.local" \
  CMAKE_BUILD_TYPE=Release \
  -j "$(c-nproc)"

make install

echo "Removing neovim source directory $neovim_source_dir"
rm -rf "$neovim_source_dir"

echo "Done. Ensure \$HOME/.local/bin is on your PATH."
