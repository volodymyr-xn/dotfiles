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
