# CTRL-o runs fzf branch search
# bindkey -s "^o" 'ch\n'

# echo "Executing .zshrc"

stty -ixon
# bindkey -v


#
# # ZSH extensions
. "$HOME/dotfiles/zsh/oh-my-zsh-config"
. "$HOME/dotfiles/zsh/aliases"
. "$HOME/dotfiles/zsh/tmux"
. "$HOME/dotfiles/zsh/functions"
. "$HOME/dotfiles/zsh/keybindings"

# ===========================
# Zsh History Configuration
# ===========================

export HISTSIZE=550000
# Explanation:
# HISTSIZE controls how many commands Zsh keeps *in memory* during the session.
# This does NOT directly determine how many get saved to the history file.
# A larger value means:
#   - you can scroll back through more commands using ↑
#   - SHARE_HISTORY can merge more data between shells
# Here it's set to 550,000 commands.

export SAVEHIST=500000
# Explanation:
# SAVEHIST controls how many commands Zsh writes to the history file (~/.zsh_history)
# when saving history.
# Only the most recent SAVEHIST commands are preserved.
# If your in-memory history exce


# Append history to the history file instead of overwriting it on exit
setopt APPEND_HISTORY
# Explanation:
# By default, the last shell to exit overwrites the entire history file.
# APPEND_HISTORY makes each shell *append* its history instead,
# preventing accidental history loss.

# Write each command to the history file immediately as it is executed
setopt INC_APPEND_HISTORY
# Explanation:
# Zsh normally writes history only when a shell exits.
# If the terminal crashes, history is lost.
# This option writes commands instantly, making history persistent and shared.

# Share history across all running Zsh sessions in real time
setopt SHARE_HISTORY
# Explanation:
# When you run a command in one terminal, it appears in the others immediately.
# Combines INC_APPEND_HISTORY + history merging behavior.

# Do not store duplicate commands in history
setopt HIST_IGNORE_ALL_DUPS
# Explanation:
# If a command already exists anywhere in history, it will not be added again.
# Keeps history clean and avoids unnecessary repetition.

# When history must be trimmed, delete duplicate entries first
setopt HIST_EXPIRE_DUPS_FIRST
# Explanation:
# If SAVEHIST is exceeded, Zsh removes *duplicates* before removing unique commands.
# Helps preserve meaningful history.

# Prevent simultaneous shells from corrupting the history file
setopt HIST_FCNTL_LOCK
# Explanation:
# Uses file locking to avoid race conditions when multiple terminals
# try to write history at the same time.
# Prevents partial writes, truncation, and corruption.


# pnpm
export PNPM_HOME="/Users/tech/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

# Enable fzf
if command -v fzf >/dev/null 2>&1; then
  source <(fzf --zsh)
fi

# # Include local settings
# [[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
#
# # Shell-GPT integration ZSH v0.2
_sgpt_zsh() {
if [[ -n "$BUFFER" ]]; then
    _sgpt_prev_cmd=$BUFFER
    BUFFER+="⌛"
    zle -I && zle redisplay
    BUFFER=$(sgpt --shell <<< "$_sgpt_prev_cmd" --no-interaction)
    zle end-of-line
fi
}
zle -N _sgpt_zsh
bindkey "^t" _sgpt_zsh
# # Shell-GPT integration ZSH v0.2

source "$HOME/dotfiles/shared_shell_rc_file"

# echo "Activating mise from zshrc"
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi

# source ~/.zsh/catppuccin_mocha-zsh-syntax-highlighting.zsh
# [ -f "${XDG_CONFIG_HOME:-$HOME/.config}"/fzf/fzf.zsh ] && source "${XDG_CONFIG_HOME:-$HOME/.config}"/fzf/fzf.zsh

export PATH="$PATH:$HOME/.local/bin"

# Dracula (previous theme):
# export FZF_DEFAULT_OPTS='--bind tab:toggle,shift-tab:toggle --color=fg:#f8f8f2,bg:#282a36,hl:#bd93f9 --color=fg+:#f8f8f2,bg+:#44475a,hl+:#bd93f9 --color=info:#ffb86c,prompt:#50fa7b,pointer:#ff79c6 --color=marker:#ff79c6,spinner:#ffb86c,header:#6272a4'
#
# Full official Catppuccin Macchiato fzf theme (explicit fg/bg, no terminal
# inheritance): https://github.com/catppuccin/fzf
# fg is purple-tinted dim white (between #ffffff and Macchiato text #cad3f5)
# so unselected items sit back; current line pops with white fg+ on bg+.
# Tab-selected items use green text to differ from the list.
# Each UI element gets its own Macchiato accent: red matches, mauve prompt,
# rosewater query, peach pointer, yellow marker, teal spinner, blue counter,
# sapphire header, lavender border, pink separator, flamingo scrollbar,
# green + sky for tab-selected items.
export FZF_DEFAULT_OPTS='--bind tab:toggle,shift-tab:toggle --color=bg+:#363a4f,bg:#24273a,spinner:#8bd5ca,hl:#ed8796 --color=fg:#e4e9fa,header:#7dc4e4,info:#8aadf4,pointer:#f5a97f --color=marker:#eed49f,fg+:#ffffff,prompt:#c6a0f6,hl+:#ed8796 --color=query:#f4dbd6,separator:#f5bde6,scrollbar:#f0c6c6 --color=selected-fg:#a6da95,selected-bg:#494d64,selected-hl:#91d7e3 --color=border:#b7bdf8,label:#cad3f5'

eval "$(c-fzf-bins --init)"

# bun completions
[ -s "/Users/tech/.bun/_bun" ] && source "/Users/tech/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# TODO: enable after a trial period if hidden-cursor leaks keep happening.
# Re-show terminal cursor before each prompt, in case a program exited
# while the cursor was hidden (leaked \e[?25l — fzf/editor/spinner killed
# before restoring it). Symptom: invisible cursor at the prompt / when
# focusing a tmux window. Manual fix meanwhile: c-restore-shell-cursor.
# To enable: uncomment the 3 lines below and reload (exec zsh).
# add-zsh-hook appends to precmd_functions instead of clobbering any
# framework precmd (oh-my-zsh/p10k/starship safe).
# Explanation:
# zsh runs precmd right before drawing each prompt — the exact moment to
# reassert cursor visibility. \e[?25h (DECTCEM set / tput cnorm) is
# zero-width and costs ~one syscall per prompt.
# autoload -Uz add-zsh-hook
# _restore_cursor() { printf '\e[?25h' }
# add-zsh-hook precmd _restore_cursor
