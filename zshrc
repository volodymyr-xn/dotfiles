# CTRL-o runs fzf branch search
# bindkey -s "^o" 'ch\n'

stty -ixon
bindkey -v
#
# # ZSH extensions
. $HOME/dotfiles/zsh/oh-my-zsh
. $HOME/dotfiles/zsh/aliases
. $HOME/dotfiles/zsh/tmux
. $HOME/dotfiles/zsh/functions
. $HOME/dotfiles/zsh/keybindings
#
# # Enable fzf
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
#
# # Include local settings
# [[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
#
source "$HOME/dotfiles/shared_shell_rc_file"

[ -f "${XDG_CONFIG_HOME:-$HOME/.config}"/fzf/fzf.zsh ] && source "${XDG_CONFIG_HOME:-$HOME/.config}"/fzf/fzf.zsh

export FZF_DEFAULT_OPTS='--color=fg:#f8f8f2,bg:#282a36,hl:#bd93f9 --color=fg+:#f8f8f2,bg+:#44475a,hl+:#bd93f9 --color=info:#ffb86c,prompt:#50fa7b,pointer:#ff79c6 --color=marker:#ff79c6,spinner:#ffb86c,header:#6272a4'
