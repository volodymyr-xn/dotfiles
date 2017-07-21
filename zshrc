BASE16_SHELL=$HOME/.config/base16-shell/
[ -n "$PS1"  ] && [ -s $BASE16_SHELL/profile_helper.sh  ] && eval "$($BASE16_SHELL/profile_helper.sh)"
. ~/.user_settings
stty -ixon
#
export EDITOR='vim'

# Use ~~ as the trigger sequence instead of the default **
export FZF_COMPLETION_TRIGGER='~~'

# Options to fzf command
export FZF_COMPLETION_OPTS='+c -x'
export FZF_DEFAULT_COMMAND='ag -g ""'

# Use ag instead of the default find command for listing candidates.
# - The first argument to the function is the base path to start traversal
# - Note that ag only lists files not directories
# - See the source code (completion.{bash,zsh}) for the details.
 _fzf_compgen_path() {
  ag -g "" "$1"
}

source $HOME/dotfiles/zsh/oh-my-zsh
source $HOME/dotfiles/zsh/aliases
source $HOME/dotfiles/zsh/tmux
source $HOME/dotfiles/zsh/functions
source $HOME/dotfiles/zsh/z.sh

# ssh
export SSH_KEY_PATH="~/.ssh/dsa_id"

export PATH="$HOME/bin:$PATH"

export RUBYOPT="-W1"

# Include local settings
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
alias cap-current-branch='GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD) cap'

# [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

. $HOME/.asdf/asdf.sh
# rbenv
export PATH="$HOME/.rbenv/bin:$PATH"
export PATH="$HOME/.rbenv/plugins/ruby-build/bin:$PATH"
eval "$(rbenv init -)"
