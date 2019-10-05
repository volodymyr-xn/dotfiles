source ~/dotfiles/shared_shell_settings

parse_git_branch() {
  git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}

# Promt styles
export PS1="\u@\h \W\[\033[32m\]\$(parse_git_branch)\[\033[00m\] $ "

export DISABLE_AUTO_TITLE=true

# Enable fzf shortcuts
[ -f ~/.fzf.bash ] && source ~/.fzf.bash
