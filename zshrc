. /etc/environment

# bindkey -s "^f" '$(fdd | fzf)\nclear\n'
# bindkey -s "^t" '$(fz)\n'
bindkey -s "^o" 'fbr\n'

# base16-shell theme
BASE16_SHELL=$HOME/.config/base16-shell/
[ -n "$PS1"  ] && [ -s $BASE16_SHELL/profile_helper.sh  ] && eval "$($BASE16_SHELL/profile_helper.sh)"

[ -f ~/.local_settings ] && source ~/.local_settings

stty -ixon

# Use vim as default editor
export EDITOR='vim'

export DISABLE_AUTO_TITLE=true

# Use ~~ as the trigger sequence instead of the default **
export FZF_COMPLETION_TRIGGER='~~'

# Options to fzf command
export FZF_COMPLETION_OPTS='+c -x'
export FZF_DEFAULT_COMMAND='ag --hidden --ignore .git -g ""'
export FZF_CTRL_T_OPTS="--preview '(highlight -O ansi -l {} 2> /dev/null || cat {} || tree -C {}) 2> /dev/null | head -200'"

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
source $HOME/dotfiles/zsh/key-bindings

# ssh
export SSH_KEY_PATH="~/.ssh/dsa_id"

# add ~/bin to PATH
export PATH="$HOME/bin:$PATH"

# add yarn bin to PATH
export PATH="$HOME/.yarn/bin:$PATH"

# add rust package manager to PATH
export PATH="$HOME/.cargo/bin:$PATH"

# add go to path
export PATH="$HOME/.go/bin:$PATH"

export RUBYOPT="-W1"

# android studio
export ANDROID_HOME=$HOME/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/tools
export PATH=$PATH:$ANDROID_HOME/platform-tools

export PATH=$PATH:~/.local/bin

# Include local settings
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
alias cap-current-branch='GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD) cap'

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

. $HOME/.asdf/asdf.sh
# rbenv
# export PATH="$HOME/.rbenv/bin:$PATH"
# export PATH="$HOME/.rbenv/plugins/ruby-build/bin:$PATH"
# eval "$(rbenv init -)"
