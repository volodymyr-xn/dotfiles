#!/usr/bin/env bash

# Apply macOS system defaults for this machine.
# Run manually after a fresh install or whenever new defaults are added.

set -euo pipefail

source "$HOME/dotfiles/macos_setup/lib/output.sh"

section "Finder"

note "Show hidden files in Finder by default"
defaults write com.apple.finder AppleShowAllFiles -bool true

section "iTerm2 — power & rendering"

note "Disable Metal renderer when on battery (GPU returns to idle between frames)"
defaults write com.googlecode.iterm2 DisableMetalWhenUnplugged -bool true

note "Cap Metal FPS at 60 (avoid ProMotion-class refresh draining battery)"
defaults write com.googlecode.iterm2 MetalMaximumFramesPerSecond -int 60

note "Reduce flicker / redundant redraws (cuts wakeups)"
defaults write com.googlecode.iterm2 ReduceFlicker -bool true

note "Hide tab activity indicator (no animation per char in noisy tabs)"
defaults write com.googlecode.iterm2 HideTabActivityIndicator -bool true

note "Disable proxy icon (skip LaunchServices lookup on every cwd change)"
defaults write com.googlecode.iterm2 EnableProxyIcon -bool false

note "Skip automatic update checks at launch"
defaults write com.googlecode.iterm2 SUEnableAutomaticChecks -bool false

section "Power management (battery only — AC unaffected)"

note "Disable Power Nap on battery (no hourly wakeups for Mail / iCloud sync)"
sudo pmset -b powernap 0

killall Finder >/dev/null 2>&1 || true

printf '\n%s✓ macOS defaults applied.%s\n' "$C_BOLD$C_GREEN" "$C_RESET"
