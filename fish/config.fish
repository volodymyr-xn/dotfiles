if status is-interactive
    # Commands to run in interactive sessions can go here
    # source ~/.fzf/shell/key-bindings.fish
    fzf_key_bindings
  alias na='xdg-open .'
# alias na='nautilus .'

# General UNIX
  alias mv='mv -iv'
  alias cp='cp -iv'
  alias df='df -h'
  alias du='du -h'
  alias dud='du -d 1 -h'
  alias duff='du -sh *'
  alias duf='duf -hide-fs squashfs '
  alias mkdir='mkdir -pv'
  alias src='source ~/.zshrc'

# Tests
  alias rs='bundle exec rspec spec'
  alias rsx='bin/spring rspec'
  alias rt='rake test'
  alias rti='rake test:integration'

# Listing files and directories
  alias l='ls -lFh'     #size,show type,human readable
  alias la='ls -lAFh'   #long list, show almost all, show type, human readable
  alias lr='ls -tRFh'   #sorted by date, recursive, show type, human readable
  alias ll='ls -l'      #long list

# Display only hidden files
  alias l.='ls -d .* --color=auto'

# Finding stuff!
  alias fd='find . -type d -name'
  alias ff='find . -type f -name'

# Tree
  alias t1='tree -CFL 1'
  alias t2='tree -CFL 2'
  alias t3='tree -CFL 3'
  alias t4='tree -CFL 4'

# Rake
  alias rake='bundle exec rake'

# Rails
  alias bx='bundle exec'

# Ctags
  alias ctags-ruby='ctags -R --languages=ruby,javascript --sort=yes  --tag-relative=yes --exclude=.git --exclude=log --exclude=node_modules . $(bundle list --paths)'
  alias ct='ctags-ruby'

# Creates new tmux session
  function tn
    tmux new -s $1
  end

# Creates new tmux session from existing directory
  function tm
    tmux new-session -As $(basename "$PWD" | tr . -)
  end

# Makes attaching to an existing tmux session easier
  function ta
    tmux attach
  end

# Makes deleting a tmux session easier
  function tk
    tmux kill-session -t $1
  end

# Kill stop tmux server and kill all sessions
  alias tka="tmux kill-server"

# List tmux sessions
  alias tl='tmux ls'

# Tmuxinator shortcut
  alias tx='tmuxinator'

# Kill all tmux sessions
  alias tka="tmux ls | cut -d : -f 1 | xargs -I {} tmux kill-session -t {}" # tmux kill all sessions

end
