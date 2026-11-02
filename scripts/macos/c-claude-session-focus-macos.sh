#!/usr/bin/env bash

# Bring the terminal running a Claude Code session forward, for the
# claude_stats menubar panel in Hammerspoon.
#
# When the session runs inside tmux, the most recently active tmux client is
# switched to its pane — preferring a client already on that session — and
# the client's ancestors are printed; otherwise the session's own. One pid
# per line, nearest first: Hammerspoon activates the first one that is an
# app (the terminal), because activating an app from a script is unreliable
# since macOS 14 made activation cooperative.
#
# Before a tmux switch, the client's location is stamped into C_TMUX_BACK
# (tmux prefix+l) and a first line "back <client pane> <session pane>" is
# printed, so Hammerspoon can arm Cmd+K the way an agent notification does.
#
# Usage: c-claude-session-focus-macos.sh <pid>

set -euo pipefail

# Hammerspoon starts this with launchd's PATH, which has no Homebrew.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
# And with no locale: tmux then prints every tab and non-ASCII character in
# its formats as "_", which breaks the tab-separated client rows.
export LANG="en_US.UTF-8"

session_pid="$1"

# Print a pid and every ancestor up to launchd, nearest first.
print_ancestors() {
  local current="$1"

  while [[ -n "$current" && "$current" -gt 1 ]]; do
    echo "$current"
    current="$(ps -o ppid= -p "$current" | tr -d ' ')"
  done
}

# The tmux pane whose tty is $1, or nothing.
pane_for_tty() {
  tmux list-panes -a -F '#{pane_tty} #{pane_id}' 2>/dev/null \
    | awk -v tty="$1" '$1 == tty { print $2; exit }'
}

# The client to switch, as "tty pid pane session:window.pane" joined by
# tabs: the most recently active one already on session $1, else the most
# recently active one at all. Tabs because session names may hold spaces
# ("dotfiles 🏡"). Its location comes from list-clients, not
# `display-message -c`, which resolves against an inherited $TMUX_PANE.
client_for_session() {
  local clients
  clients="$(tmux list-clients \
    -F $'#{client_activity}\t#{client_session}\t#{client_tty}\t#{client_pid}\t#{pane_id}\t#S:#I.#P' 2>/dev/null \
    | sort -rn)"

  local on_session
  on_session="$(awk -F'\t' -v OFS='\t' -v session="$1" '$2 == session { print $3, $4, $5, $6; exit }' <<<"$clients")"

  if [[ -n "$on_session" ]]; then
    echo "$on_session"
    return
  fi

  awk -F'\t' -v OFS='\t' 'NR == 1 { print $3, $4, $5, $6 }' <<<"$clients"
}

session_tty="$(ps -o tty= -p "$session_pid" | tr -d ' ')"

if [[ -n "$session_tty" && "$session_tty" != "??" ]] && command -v tmux >/dev/null; then
  pane="$(pane_for_tty "/dev/$session_tty")"

  if [[ -n "$pane" ]]; then
    tmux_session="$(tmux display-message -p -t "$pane" '#{session_name}')"
    client="$(client_for_session "$tmux_session")"

    if [[ -n "$client" ]]; then
      IFS=$'\t' read -r client_tty client_pid client_pane client_location <<<"$client"

      tmux set-environment -g C_TMUX_BACK "$client_location"
      echo "back $client_pane $pane"

      tmux switch-client -c "$client_tty" -t "$pane"
      tmux select-window -t "$pane"
      tmux select-pane -t "$pane"

      print_ancestors "$client_pid"
      exit 0
    fi
  fi
fi

print_ancestors "$session_pid"
