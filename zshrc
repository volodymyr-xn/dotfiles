# CTRL-o runs fzf branch search
# bindkey -s "^o" 'ch\n'

stty -ixon

# ZSH extensions
source $HOME/dotfiles/zsh/oh-my-zsh
source $HOME/dotfiles/zsh/aliases
source $HOME/dotfiles/zsh/tmux
source $HOME/dotfiles/zsh/functions
source $HOME/dotfiles/zsh/keybindings

# Enable fzf
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Include local settings
# [[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

source ~/dotfiles/shared_shell_rc_file
