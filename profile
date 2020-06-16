# vim: syntax=bash
# nvim: syntax=bash

# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
#umask 022

# If running bash
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
      . "$HOME/.bashrc"
    fi
fi

# If running zsh
if [ -n "$ZSH_VERSION" ]; then
    # include .zshrc if it exists
    if [ -f "$HOME/.zshrc" ]; then
      . "$HOME/.zshrc"
    fi
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi

# set PATH so it includes user's private bin if it exists
# if [ -d "$HOME/.local/bin" ] ; then
#     PATH="$HOME/.local/bin:$PATH"
# fi

# Use vim as default editor
export EDITOR='nvim'

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
export PKG_CONFIG_PATH=$PKG_CONFIG_PATH:$VIPSHOME/lib/pkgconfig
export PYTHONPATH=$VIPSHOME/lib/python2.7/site-packages
export GI_TYPELIB_PATH="/usr/local/lib/girepository-1.0"

# Configule BASE16 shell colorthemes
export BASE16_SHELL=$HOME/.config/base16-shell/

# Use ag instead of the default find command for listing candidates.
# - The first argument to the function is the base path to start traversal
# - Note that ag only lists files not directories
# - See the source code (completion.{bash,zsh}) for the details.
_fzf_compgen_path() {
  ag -g "" "$1"
}

# Homebrew settings
export HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
export HOMEBREW_CELLAR="$HOMEBREW_PREFIX/Cellar"
export HOMEBREW_REPOSITORY="$HOMEBREW_PREFIX/Homebrew"

# gopath dir
export GOPATH="$HOME/.programing_languages/go"

if [[ -z $TMUX ]]; then
  # Add linuxbrew to PATH
  export PATH="$PATH:$HOMEBREW_PREFIX/bin:$HOMEBREW_PREFIX/sbin"
  # Old format(homebrew binaries has lowest priority
  # With this i have openssl bug(broken certificates), that prevents me from install
  # Docker or just use "curl -fsSL"
  # export PATH="$HOMEBREW_PREFIX/bin:$HOMEBREW_PREFIX/sbin:$PATH"

  # Add ~/bin to PATH
  export PATH="$HOME/bin:$PATH"

  # Add dotfiles bin directory to PATH
  export PATH="$HOME/dotfiles/bin:$PATH"

  # Add vips to PATH
  export PATH="$PATH:$VIPSHOME/bin"

  # Add yarn bin to PATH
  export PATH="$HOME/.yarn/bin:$PATH"

  # Add rust package manager binaries to PATH
  export PATH="$HOME/.programing_languages/cargo/bin:$PATH"

  # Add packages installed by go to path
  export PATH="$GOPATH/bin:$PATH"

  # Add local binaries to path
  export PATH="$HOME/.local/bin:$PATH"
fi

# Ruby verbose mode
export RUBYOPT="-W1"

# Set Onedark fzf theme
# export FZF_DEFAULT_OPTS='
# --color=dark
# --color=fg:-1,bg:-1,hl:#c678dd,fg+:#ffffff,bg+:-1,hl+:#d858fe
# --color=info:#98c379,prompt:#61afef,pointer:#e5c07b,marker:#e5c07b,spinner:#61afef,header:#61afef
# '
# FZF Dracula colorscheme
# export FZF_DEFAULT_OPTS=$FZF_DEFAULT_OPTS'
# --color=dark
# --color=fg:-1,bg:-1,hl:#e5c07f,fg+:-1,bg+:-1,hl+:#5fff87
# --color=info:#af87ff,prompt:#5fff87,pointer:#e5c07b,marker:#ff87d7,spinner:#ff87d7
# '

# DEPRECATED
# rbenv
# export PATH="$HOME/.rbenv/bin:$PATH"
# export PATH="$HOME/.rbenv/plugins/ruby-build/bin:$PATH"
# eval "$(rbenv init -)"

### XDG variables

# Good to have this defined mannualy
export XDG_USER_CONFIG_DIR=$HOME/.config

# Good to have this defined mannualy
# XDG config dir
export XDG_CONFIG_HOME=$HOME/.config

# XDG_DATA HOME
export XDG_DATA_HOME=$HOME/.local/share

# JAVA_HOME="/usr/lib/jvm/java-8-openjdk-amd64/"

# SSL certificates workaround for homebrew version of openssl
export SSL_CERT_DIR=/usr/lib/ssl/certs/
export SSL_CERT_FILE=/usr/lib/ssl/certs/ca-certificates.crt
export WINEPREFIX=~/WineVersions/wine-5

local_profile_path="$HOME/.local_profile"

# If local profile file exist - source it
if [ -f "$local_profile_path" ] ; then
  source "$local_profile_path"
fi
