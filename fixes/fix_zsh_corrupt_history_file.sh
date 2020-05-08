#!/usr/bin/env sh

cp ~/.zsh_history ~/.zsh_history_bad
strings ~/.zsh_history_bad > ~/.zsh_history
fc -R ~/.zsh_history
rm ~/.zsh_history_bad
