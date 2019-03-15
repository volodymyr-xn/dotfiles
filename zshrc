. /etc/environment

# CTRL-o runs fzf branch search
bindkey -s "^o" 'ch\n'

# Base16-shell theme
BASE16_SHELL=$HOME/.config/base16-shell/

# Enable Base16-shell themes
[ -n "$PS1"  ] && [ -s $BASE16_SHELL/profile_helper.sh  ] && eval "$($BASE16_SHELL/profile_helper.sh)"

stty -ixon

# Use vim as default editor
export EDITOR='vim'

export DISABLE_AUTO_TITLE=true

# Use ~~ as the trigger sequence instead of the default **
export FZF_COMPLETION_TRIGGER='~~'

# Options to fzf command
export FZF_COMPLETION_OPTS='+c -x'

# FZF will ignore .git and hidden files
export FZF_DEFAULT_COMMAND='ag --hidden --ignore .git -g ""'

# DEPRECATED
# export FZF_CTRL_T_OPTS="--preview '(highlight -O ansi -l {} 2> /dev/null || cat {} || tree -C {}) 2> /dev/null | head -200'"

# libvips support
export VIPSHOME=/usr/local
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$VIPSHOME/lib
export PATH=$PATH:$VIPSHOME/bin
export PKG_CONFIG_PATH=$PKG_CONFIG_PATH:$VIPSHOME/lib/pkgconfig
export MANPATH=$MANPATH:$VIPSHOME/man
export PYTHONPATH=$VIPSHOME/lib/python2.7/site-packages
export GI_TYPELIB_PATH="/usr/local/lib/girepository-1.0"

# Use ag instead of the default find command for listing candidates.
# - The first argument to the function is the base path to start traversal
# - Note that ag only lists files not directories
# - See the source code (completion.{bash,zsh}) for the details.
_fzf_compgen_path() {
  ag -g "" "$1"
}

# ZSH extensions
source $HOME/dotfiles/zsh/oh-my-zsh
source $HOME/dotfiles/zsh/aliases
source $HOME/dotfiles/zsh/tmux
source $HOME/dotfiles/zsh/functions
source $HOME/dotfiles/zsh/key-bindings

# # SSH DEPRECATED
# export SSH_KEY_PATH="~/.ssh/dsa_id"

# Add ~/bin to PATH
# export PATH="$HOME/bin:$PATH"

# Add yarn bin to PATH
export PATH="$HOME/.yarn/bin:$PATH"

# Add rust package manager to PATH
export PATH="$HOME/.cargo/bin:$PATH"

# Add go to path
export PATH="$HOME/.go/bin:$PATH"

# gopath dir
export GOPATH="$HOME/go"

# add packages installed by go to path
export PATH="$GOPATH/bin:$PATH"

# Ruby verbose mode
export RUBYOPT="-W1"

export PATH="$HOME/.local/bin:$PATH"

# Add linuxbrew to PATH
export HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
export HOMEBREW_CELLAR="$HOMEBREW_PREFIX/Cellar"
export HOMEBREW_REPOSITORY="$HOMEBREW_PREFIX/Homebrew"
export PATH="$PATH:$HOMEBREW_PREFIX/bin:$HOMEBREW_PREFIX/sbin"

# Better less highlight
export LESS_TERMCAP_mb=$'\E[1;31m'     # begin bold
export LESS_TERMCAP_md=$'\E[1;36m'     # begin blink
export LESS_TERMCAP_me=$'\E[0m'        # reset bold/blink
export LESS_TERMCAP_so=$'\E[01;44;0m'  # begin reverse video
export LESS_TERMCAP_se=$'\E[0m'        # reset reverse video
export LESS_TERMCAP_us=$'\E[1;32m'     # begin underline
export LESS_TERMCAP_ue=$'\E[0m'        # reset underline
export GROFF_NO_SGR=1                  # for konsole and gnome-terminal

# Include local settings
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
alias cap-current-branch='GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD) cap'

# Enable fzf
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

export FZF_DEFAULT_OPTS=$FZF_DEFAULT_OPTS'
--color=dark
--color=fg:-1,bg:-1,hl:#c678dd,fg+:#ffffff,bg+:#4b5263,hl+:#d858fe
--color=info:#98c379,prompt:#61afef,pointer:#be5046,marker:#e5c07b,spinner:#61afef,header:#61afef
'

# Enable asdf
. $HOME/.asdf/asdf.sh

# DEPRECATED
# rbenv
# export PATH="$HOME/.rbenv/bin:$PATH"
# export PATH="$HOME/.rbenv/plugins/ruby-build/bin:$PATH"
# eval "$(rbenv init -)"
