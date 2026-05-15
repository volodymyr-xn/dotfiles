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

# echo "Executing .profile"

# If running bash
# if [ -n "$BASH_VERSION" ]; then
#     # include .bashrc if it exists
#     if [ -f "$HOME/.bashrc" ]; then
#       . "$HOME/.bashrc"
#     fi
# fi

# If running zsh
# if [ -n "$ZSH_VERSION" ]; then
#     # include .zshrc if it exists
#     if [ -f "$HOME/.zshrc" ]; then
#       . "$HOME/.zshrc"
#     fi
# fi

export HISTSIZE=550000
export SAVEHIST=500000

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi

# set PATH so it includes user's private bin if it exists
# if [ -d "$HOME/.local/bin" ] ; then
#     PATH="$HOME/.local/bin:$PATH"
# fi


# Use vim as default editor
# export EDITOR='nvim'

# Use nvim as IDE editor but regular vim as more lighweiht editor for 3rd party
# apps inline edit intergrations, so prefer less plugin and configuration heavy
# editor, to make integrated edit startup more instant
export EDITOR='vim'

export DISABLE_AUTO_TITLE=true

# Use ~~ as the trigger sequence instead of the default **
export FZF_COMPLETION_TRIGGER='~~'

# Options to fzf command
export FZF_COMPLETION_OPTS='+c -x'

# FZF will ignore .git and hidden files
# export FZF_DEFAULT_COMMAND='ag --hidden --ignore .git -g ""'
# export FZF_DEFAULT_COMMAND='fd --type file --hidden --no-ignore'
# export FZF_DEFAULT_COMMAND="command rg -uu -g '!.git' --files"
export FZF_DEFAULT_COMMAND='rg --files --hidden --glob "!.git/*"'

_fzf_compgen_path() {
  command rg -uu -g '!.git' --files "${1}"
}
export FZF_CTRL_T_OPTS="--preview 'command bat --color=always --line-range :500 {}' ${FZF_CTRL_T_OPTS}"
#
# export FZF_DEFAULT_OPTS="--ansi --preview-window 'right:60%' --preview 'bat --color=always --style=header,grid --line-range :300 {}'"

# DEPRECATED
# export FZF_CTRL_T_OPTS="--preview '(highlight -O ansi -l {} 2> /dev/null || cat {} || tree -C {}) 2> /dev/null | head -200'"

# libvips support
export VIPSHOME=/usr/local
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$VIPSHOME/lib
export PKG_CONFIG_PATH=$PKG_CONFIG_PATH:$VIPSHOME/lib/pkgconfig
export PYTHONPATH=$VIPSHOME/lib/python2.7/site-packages
export GI_TYPELIB_PATH="/usr/local/lib/girepository-1.0"

# Configule BASE16 shell colorthemes
export BASE16_SHELL="$HOME/.config/base16-shell/"

# Use ag instead of the default find command for listing candidates.
# - The first argument to the function is the base path to start traversal
# - Note that ag only lists files not directories
# - See the source code (completion.{bash,zsh}) for the details.
# _fzf_compgen_path() {
  # ag -g "" "$1"
# }
#

if [[ $(uname -m) == 'arm64' ]]; then
  export HOMEBREW_PREFIX="/opt/homebrew"
else
  export HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
fi

# Homebrew settings
export HOMEBREW_CELLAR="$HOMEBREW_PREFIX/Cellar"
export HOMEBREW_REPOSITORY="$HOMEBREW_PREFIX/Homebrew"

# gopath dir
export GOPATH="$HOME/.programing_languages/go"

# if [[ -z $TMUX ]]; then
  # Add homebrew to PATH
  #

# if [[ $(uname -m) == 'arm64' ]]; then
  # export PATH="$HOMEBREW_PREFIX/bin:$HOMEBREW_PREFIX/sbin:$PATH"
# else
# export PATH="$PATH:$HOMEBREW_PREFIX/bin:$HOMEBREW_PREFIX/sbin"
# fi

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
  export PATH="$HOME/.programing_languages/rust/cargo/bin:$PATH"

  # Add packages installed by go to path
  export PATH="$GOPATH/bin:$PATH"

  # Add local binaries to path
  export PATH="$HOME/.local/bin:$PATH"

  export PATH="${PATH}:/usr/x86_64-w64-mingw32/bin"
# fi

# Ruby verbose mode
# export RUBYOPT="-W1"

if [[ -f "/opt/homebrew/bin/brew" ]] ; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
  export LDFLAGS="$LDFLAGS -L$(brew --prefix jemalloc)/lib"
  export CPPFLAGS="$CPPFLAGS -I$(brew --prefix jemalloc)/include"
  export PKG_CONFIG_PATH="$(brew --prefix jemalloc)/lib/pkgconfig:$PKG_CONFIG_PATH"
  export PKG_CONFIG_PATH="/opt/homebrew/bin/pkg-config:$(brew --prefix icu4c)/lib/pkgconfig:$(brew --prefix curl)/lib/pkgconfig:$(brew --prefix zlib)/lib/pkgconfig"
  # export RUBY_CONFIGURE_OPTS="--with-readline-dir=$(brew --prefix readline)"
  export RUBY_CONFIGURE_OPTS="--with-jemalloc --enable-yjit --with-jemalloc-dir=$(brew --prefix jemalloc) --with-readline-dir=$(brew --prefix readline)  --with-openssl=$(brew --prefix openssl) --with-openssl-dir=$(brew --prefix openssl@3)"
  # export RUBY_CONFIGURE_OPTS="--with-readline-dir=$(brew --prefix readline)  --with-openssl=$(brew --prefix openssl) --with-openssl-dir=$(brew --prefix openssl)"
  # export RUBY_CONFIGURE_OPTS=""
else
  # export RUBY_CONFIGURE_OPTS=""
  export RUBY_CONFIGURE_OPTS="--with-jemalloc --enable-yjit"
  export MALLOC_ARENA_MAX=2
fi


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
#export XDG_USER_CONFIG_DIR=$HOME/.config

# Good to have this defined mannualy
# XDG config dir
#export XDG_CONFIG_HOME=$HOME/.config

# XDG_DATA HOME
#export XDG_DATA_HOME=$HOME/.local/share

#export GTK_THEME=Adwaita:dark

# Docker config dir
export DOCKER_CONFIG="$HOME/.config/docker"

# JAVA_HOME="/usr/lib/jvm/java-8-openjdk-amd64/"

# SSL certificates workaround for homebrew version of openssl
# WARNING: ENABLE ONLY IF HOMEBREW IS USED
# OTHERWISE BREAKS HTTPS REQUESTS IN SYSTEM
# export SSL_CERT_DIR=/usr/lib/ssl/certs/
# export SSL_CERT_FILE=/usr/lib/ssl/certs/ca-certificates.crt

# Set default wineprefix

# True color support in TMUX
export TERM=xterm-256color

# Better less highlight
export LESS_TERMCAP_mb=$'\E[1;31m'     # begin bold
export LESS_TERMCAP_md=$'\E[1;36m'     # begin blink
export LESS_TERMCAP_me=$'\E[0m'        # reset bold/blink
export LESS_TERMCAP_so=$'\E[7;93m'     # begin reverse video
export LESS_TERMCAP_se=$'\E[0m'        # reset reverse video
export LESS_TERMCAP_us=$'\E[1;32m'     # begin underline
export LESS_TERMCAP_ue=$'\E[0m'        # reset underline
export GROFF_NO_SGR=1                  # for konsole and gnome-terminal

# Use less as man page viewer
# export MANPAGER="less"
# Use neovim as man page viewer
export MANPAGER='nvim +Man!'

export BAT_THEME="Catppuccin Mocha"

# Always use number of processing cores with make
# shopt -s checkwinsize

export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock

# export ASDF_FORCE_PREPEND=yes


# Enable asdf
# if [ -f "$HOME/.asdf/asdf.sh" ]; then
#   echo 'Source asdf from profile'
#   source $HOME/.asdf/asdf.sh
# fi

# asdf 0.16+
# export ASDF_DATA_DIR="$HOME/.asdf"
# export PATH="$ASDF_DATA_DIR/shims:$PATH"


local_profile_path="$HOME/.local_profile"

# If local profile file exist - source it
if [ -f "$local_profile_path" ] ; then
  . "$local_profile_path"
fi

# if [ -f "$HOME/.cargo/env" ] ; then
#   . "$HOME/.cargo/env"
# fi

if [[ -f "/Users/tech/.local/bin/mise" ]] ; then
  echo "Activating mise from profile"
  eval "$(activate zsh)"
fi

export PATH="$PATH:$HOME/.local/bin"
. "$HOME/.cargo/env"

# Reduce meory usage by malloc(ruby garbage collection at the moment)
export MALLOC_ARENA_MAX=2

# Test change
alias ag='rg --follow --column --color always'
