#!/usr/bin/env bash

# Install this repo's sudoers.d drop-ins into /etc/sudoers.d.
# Run manually after a fresh install or whenever a drop-in changes.
#
# Every file in macos/sudoers.d/ is a template: `${USER}` resolves to the
# invoking account, so the repo copy stays machine-independent.
#
# Each rendered file is validated with `visudo -cf` BEFORE it is installed —
# an invalid drop-in can lock the machine out of sudo entirely.
#
# Already-current files are skipped, so re-running is cheap and idempotent.

set -euo pipefail

DOTFILES_DIR="$HOME/dotfiles"
SOURCE_DIR="$DOTFILES_DIR/macos/sudoers.d"
TARGET_DIR="/etc/sudoers.d"

source "$DOTFILES_DIR/macos/lib/output.sh"

# Render one template with bash's own global substitution — no gettext, so
# this works on a stock macOS install before Homebrew exists.
#
# Only `${USER}` is substituted, on purpose. Bare `envsubst` (control_panel's
# approach) expands every ${VAR} in the file, and an unset name becomes an
# empty string: a sudoers line that loses its user silently changes who the
# rule grants root to. `eval "cat <<EOF"` is worse still — it would execute
# any $(...) in a file whose purpose is granting passwordless root.
render_template() {
  local content
  content="$(<"$1")"

  printf '%s\n' "${content//\$\{USER\}/$USER}"
}

# Rendered templates live here until they are installed or discarded.
STAGING_DIR="$(mktemp -d)"

section "sudoers drop-ins"

if [[ ! -d "$SOURCE_DIR" ]]; then
  fail "no templates found at $SOURCE_DIR"
  exit 1
fi

# Ask for the password once up front, so the per-file sudo calls below run
# without interleaving prompts into the output.
sudo -v

installed_count=0

for template in "$SOURCE_DIR"/*; do
  [[ -f "$template" ]] || continue

  name="${template##*/}"
  rendered="$STAGING_DIR/$name"
  target="$TARGET_DIR/$name"

  render_template "$template" > "$rendered"
  chmod 440 "$rendered"

  if ! sudo visudo -cf "$rendered" >/dev/null 2>&1; then
    fail "$name is not valid sudoers syntax — not installed"
    continue
  fi

  if sudo cmp -s "$rendered" "$target" 2>/dev/null; then
    skip "$name already current"
    continue
  fi

  sudo install -m 440 -o root -g wheel "$rendered" "$target"
  note "$name installed for user $USER"
  installed_count=$((installed_count + 1))
done

if (( installed_count == 0 )); then
  skip "nothing to install"
fi
