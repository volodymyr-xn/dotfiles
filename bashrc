parse_git_branch() {
  git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}

# echo "Bash init"

# Promt styles
export PS1="\u@\h \W\[\033[32m\]\$(parse_git_branch)\[\033[00m\] $ "

export DISABLE_AUTO_TITLE=true

source ~/dotfiles/shared_shell_rc_file

# Enable fzf shortcuts (old)
# [ -f ~/.fzf.bash ] && source ~/.fzf.bash

# Enable fzf shortcuts
#[ -f "${XDG_CONFIG_HOME:-$HOME/.config}"/fzf/fzf.bash ] && source "${XDG_CONFIG_HOME:-$HOME/.config}"/fzf/fzf.bash
#. "$HOME/.cargo/env"


[ -f "${XDG_CONFIG_HOME:-$HOME/.config}"/fzf/fzf.bash ] && source "${XDG_CONFIG_HOME:-$HOME/.config}"/fzf/fzf.bash
