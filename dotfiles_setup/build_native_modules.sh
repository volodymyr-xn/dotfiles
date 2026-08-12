#!/usr/bin/env bash

# Build every native module for the OS this runs on.
#
# Sources live in native_modules/<platform>/ and the binaries land in
# bin_native/<platform>/, which the profile adds to PATH for that OS only.
# Run once after cloning, and again whenever a module's source changes.

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULES_DIR="$DOTFILES_DIR/native_modules"

# Set per OS below, and read by every build_* function.
BIN_DIR=""
PLATFORM=""

# Compile one Swift source into a command named after the file. Any extra
# arguments are passed to swiftc (framework flags and the like).
build_swift_module() {
  local source_file="$1"
  shift

  local binary_name
  binary_name="$(basename "${source_file%.swift}")"

  swiftc -O "$@" -o "$BIN_DIR/$binary_name" "$source_file"

  echo "built $BIN_DIR/$binary_name"
}

# SMC sensor reader. The key sets it ships are Apple Silicon only, so the
# binary is pointless on an Intel Mac.
build_sensor_temps_macos() {
  if [[ "$(uname -m)" != "arm64" ]]; then
    echo "skipped c-sensor-temps-macos: Apple Silicon only" >&2
    return
  fi

  build_swift_module "$MODULES_DIR/macos/c-sensor-temps-macos.swift" \
    -framework IOKit -framework SystemConfiguration
}

build_macos_modules() {
  build_sensor_temps_macos
}

build_linux_modules() {
  echo "no linux native modules yet"
}

case "$(uname -s)" in
  Darwin)
    PLATFORM="macos"
    ;;
  Linux)
    PLATFORM="linux"
    ;;
  *)
    echo "build_native_modules: unsupported OS $(uname -s)" >&2
    exit 1
    ;;
esac

BIN_DIR="$DOTFILES_DIR/bin_native/$PLATFORM"
mkdir -p "$BIN_DIR"

"build_${PLATFORM}_modules"
