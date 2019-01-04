#!/usr/bin/env bash

installation_log() {
  local fmt="$1"; shift
  # shellcheck disable=SC2059
  printf "\n[DOTFILES] $fmt\n" "$@"
}


#===============================================================
#================= Configuration ===============================
#===============================================================

set -e # Terminate script if anything exits with a non-zero value
set -u # Prevent unset variables

files_to_copy="\
      vim tmux zsh ackrc asdfrc ctags config.reek gemrc \
      gitconfig gitignore_global gitmessage npmrc zshrc \
      inputrc pryrc default-gems asdfrc bashrc"

DOTFILES_DIR=$HOME/dotfiles


#===============================================================
#================= Instalation =================================
#===============================================================

installation_log "Installing dotfiles..."

# Copy configuration files
for file in $files_to_copy; do

  # If configuration file alreay present - backup it
  if [ -f $HOME/.$file ]; then
    installation_log ".$file already present. Backing up..."

    cp $HOME/.$file "$HOME/.${file}_backup"

    rm -f $HOME/.$file
  fi

  installation_log "-> Linking $DOTFILES_DIR/$file to $HOME/.$file..."

  ln -nfs "$DOTFILES_DIR/$file" "$HOME/.$file"
done


# Backup existing tmux config
if [ -f $HOME/.tmux.conf ]; then
  installation_log ".tmux.conf already present. Backing up..."
  cp $HOME/.tmux.conf "$HOME/.tmux_conf_backup"
  rm -f $HOME/.tmux.conf
fi

# Copy tmux config
ln -sf ~/dotfiles/tmux/tmux.conf ~/.tmux.conf

touch ~/.user_settings

# Create bin dir in user home for custom scripts and executables
mkdir -p ~/bin

# ./fonts/install.sh

# Simlink custom linux util scripts
ln -sf ~/dotfiles/bin/toggle-window-focus ~/bin/toggle-window-focus

installation_log "Dotfiles installation complete!"
