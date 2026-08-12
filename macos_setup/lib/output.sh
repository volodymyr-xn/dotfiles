#!/usr/bin/env bash

# Shared terminal output helpers for the macos_setup/ scripts.
# Source it, do not execute:
# `source "$DOTFILES_DIR/macos_setup/lib/output.sh"`

# Color helpers — only emit ANSI escapes when stdout is a TTY.
if [[ -t 1 ]]; then
  C_BOLD=$'\033[1m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_RED=$'\033[31m'
  C_CYAN=$'\033[36m'
  C_RESET=$'\033[0m'
else
  C_BOLD=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_CYAN=""; C_RESET=""
fi

# Print a section header before a group of related steps.
section() {
  printf '\n%s▌ %s%s\n' "$C_BOLD$C_CYAN" "$1" "$C_RESET"
}

# Print a green check mark and what was just done.
note() {
  printf '  %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$1"
}

# Print a yellow dash for a step that was intentionally skipped.
skip() {
  printf '  %s–%s %s\n' "$C_YELLOW" "$C_RESET" "$1"
}

# Print a red cross for a failed step; callers decide whether to abort.
fail() {
  printf '  %s✗%s %s\n' "$C_RED" "$C_RESET" "$1" >&2
}
