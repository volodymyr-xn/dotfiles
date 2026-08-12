#!/usr/bin/env bash

# Wire up the Docker toolchain on macOS.
# Homebrew's `docker` formula ships the CLI only: the daemon comes from
# Colima, and buildx/compose are separate formulae whose plugin binaries
# Docker will not find on its own. Run manually or via 1_setup.sh.

set -euo pipefail

source "$HOME/dotfiles/macos_setup/lib/output.sh"

# Colima VM sizing. The defaults (2 CPU / 2 GB) are too small to build
# amd64 images under QEMU emulation, which Kamal deploys rely on.
COLIMA_CPU=6
COLIMA_MEMORY=12
COLIMA_DISK=100

section "Docker CLI plugins"

# Docker looks for plugins in $DOCKER_CONFIG/cli-plugins, not the stock
# ~/.docker/cli-plugins, whenever DOCKER_CONFIG is set. profile exports it,
# but this script also runs before profile is sourced on a fresh machine.
docker_config_dir="${DOCKER_CONFIG:-$HOME/.config/docker}"
plugin_dir="$docker_config_dir/cli-plugins"
brew_plugin_dir="$(brew --prefix)/lib/docker/cli-plugins"

if [[ ! -d "$brew_plugin_dir" ]]; then
  fail "No Homebrew plugin dir at $brew_plugin_dir — is docker-buildx installed?"
  exit 1
fi

# A dangling $DOCKER_CONFIG symlink makes mkdir -p fail with a bare ENOENT
# on the child path, which reads as a permission problem. Say what it is.
if [[ -L "$docker_config_dir" && ! -e "$docker_config_dir" ]]; then
  fail "$docker_config_dir is a broken symlink to $(readlink "$docker_config_dir")"
  exit 1
fi

mkdir -p "$plugin_dir"

for plugin_binary in "$brew_plugin_dir"/docker-*; do
  plugin_name="$(basename "$plugin_binary")"
  ln -sfn "$plugin_binary" "$plugin_dir/$plugin_name"
  note "Linked $plugin_name"
done

section "Colima"

if ! command -v colima >/dev/null 2>&1; then
  fail "colima not installed — run brew bundle first"
  exit 1
fi

if colima status >/dev/null 2>&1; then
  skip "Colima already running"
else
  note "Starting Colima ($COLIMA_CPU CPU / ${COLIMA_MEMORY}GB / ${COLIMA_DISK}GB disk)"
  colima start \
    --cpu "$COLIMA_CPU" \
    --memory "$COLIMA_MEMORY" \
    --disk "$COLIMA_DISK" \
    --vm-type vz
fi

section "Verifying"

# DOCKER_HOST is only correct on Linux (rootless docker). If an old shell
# exported the macOS-broken value, unset it for these checks.
if docker_version="$(env -u DOCKER_HOST docker buildx version 2>/dev/null)"; then
  note "buildx: $docker_version"
else
  fail "docker buildx still not found"
  exit 1
fi

if server_version="$(env -u DOCKER_HOST docker info --format '{{.ServerVersion}}' 2>/dev/null)"; then
  note "Daemon reachable: $server_version"
else
  fail "Cannot reach the Docker daemon"
  exit 1
fi

printf '\n%s✓ Docker toolchain ready.%s\n' "$C_BOLD$C_GREEN" "$C_RESET"
