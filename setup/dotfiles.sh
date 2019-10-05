#!/usr/bin/env bash

installation_log() {
  local fmt="$1"; shift
  # shellcheck disable=SC2059
  printf "\n[DOTFILES] $fmt\n" "$@"
}

backup_file() {
  # If file alreay present - backup it
  if [ -f $HOME/.$1 ]; then
    installation_log ".$1 already present. Backing up..."

    cp $HOME/.$1 "$HOME/.${1}_backup"

    rm -f $HOME/.$1
  fi
}


symlink_file() {
  installation_log "-> Linking $DOTFILES_DIR/$1 to $HOME/.$1..."

  ln -nfs "$DOTFILES_DIR/$1" "$HOME/.$1"
}

setup_settings_file() {
  backup_file $1
  symlink_file $1
}


#===============================================================
#================= Configuration ===============================
#===============================================================

set -e # Terminate script if anything exits with a non-zero value
set -u # Prevent unset variables

files_to_symlink="\
      vim tmux zsh ackrc asdfrc ctags config.reek gemrc \
      gitconfig gitignore_global gitmessage npmrc zshrc \
      inputrc pryrc default-gems asdfrc bashrc editorconfig"

DOTFILES_DIR=$HOME/dotfiles


#===============================================================
#================= Instalation =================================
#===============================================================

installation_log "Installing dotfiles..."

# Symlink configuration files
for file in $files_to_symlink; do
  setup_settings_file $file
done

# Create local profile file if exist
touch $HOME/local_profile

# Backup existing Tmux config
backup_file "tmux.conf"

# Copy Tmux config
installation_log "Linking .tmux.conf"
ln -sf $DOTFILES_DIR/tmux/tmux.conf ~/.tmux.conf

# Link Alacrity config
installation_log "Linking alacritty.yml"
mkdir -p ~/.config/alacritty/
ln -sf $DOTFILES_DIR/alacritty.yml ~/.config/alacritty/alacritty.yml

# Install Neovim config
# Create directory for neovim config
installation_log "Linking init.vim"
mkdir -p ~/.config/nvim/
ln -sf $DOTFILES_DIR/vim/init.vim ~/.config/nvim/init.vim

# Create ~/bin dir in user home for custom scripts and executables
mkdir -p ~/bin

# ./fonts/install.sh

# Symlink custom linux util scripts
ln -sf ~/dotfiles/bin/toggle-window-focus ~/bin/toggle-window-focus

# Symlink file templates
ln -sf ~/dotfiles/file-templates/gnome/* ~/Templates

installation_log "Dotfiles installation complete!"
