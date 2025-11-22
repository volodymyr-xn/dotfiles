# CTRL-o runs fzf branch search
# bindkey -s "^o" 'ch\n'

# echo "Executing .zshrc"

stty -ixon
bindkey -v
#
# # ZSH extensions
. $HOME/dotfiles/zsh/oh-my-zsh-config
. $HOME/dotfiles/zsh/aliases
. $HOME/dotfiles/zsh/tmux
. $HOME/dotfiles/zsh/functions
. $HOME/dotfiles/zsh/keybindings


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


export FZF_DEFAULT_OPTS='--color=fg:#f8f8f2,bg:#282a36,hl:#bd93f9 --color=fg+:#f8f8f2,bg+:#44475a,hl+:#bd93f9 --color=info:#ffb86c,prompt:#50fa7b,pointer:#ff79c6 --color=marker:#ff79c6,spinner:#ffb86c,header:#6272a4'

export PATH="$PATH:$HOME/.local/bin"

# Added by Antigravity
export PATH="/Users/tech/.antigravity/antigravity/bin:$PATH"
