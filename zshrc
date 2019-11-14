source ~/dotfiles/shared_shell_settings

# CTRL-o runs fzf branch search
# bindkey -s "^o" 'ch\n'

# CTRL-o runs fzf switch tmux session
# bindkey -s "^o" "tmux split-window -h 'fzf-switch-tmux-session'\n"
bindkey -s "^o" 'fzf-switch-tmux-session\n'


stty -ixon

# ZSH extensions
source $HOME/dotfiles/zsh/oh-my-zsh
source $HOME/dotfiles/zsh/aliases
source $HOME/dotfiles/zsh/tmux
source $HOME/dotfiles/zsh/functions
source $HOME/dotfiles/zsh/key-bindings

# Enable fzf
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Include local settings
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
