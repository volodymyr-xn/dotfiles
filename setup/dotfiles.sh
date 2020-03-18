#!/usr/bin/env bash

DOTFILES_DIR=$HOME/dotfiles

installation_log() {
  local fmt="$1"; shift
  # shellcheck disable=SC2059
  printf "\n✨ \e[32m(Dotfiles) $fmt\n" "$@"
}

symlink_to_destination() {
  target=$1
  destination=$2

  installation_log "-> Linking $target to $destination..."

  ln -nfs "$target" "$destination"
}

symlink_file_to_home_dir() {
  symlink_to_destination "$DOTFILES_DIR/$1" "$HOME/.$1"
}

symlink_fallback_file_to_home_dir() {
  file_basename=$(basename $1)
  symlink_to_destination "$DOTFILES_DIR/$1" "$HOME/.$file_basename"
}

symlink_directory_to_config_dir() {
  symlink_to_destination "$DOTFILES_DIR/$1" "$HOME/.config/$1"
}

#===============================================================
#================= Configuration ===============================
#===============================================================

set -e # Terminate script if anything exits with a non-zero value
set -u # Prevent unset variables

files_to_symlink="\
      vim tmux zsh ackrc asdfrc ctags gemrc \
      gitconfig gitignore_global gitmessage npmrc zshrc \
      inputrc default-gems asdfrc bashrc editorconfig \
      eslintrc.js config.reek stylelint"

dirs_to_symlink="alacritty bundle kitty rofi rubocop pry htop"
fallback_files_to_symlink="rubocop/rubocop.yml tmux/tmux.conf"

#===============================================================
#================= Instalation =================================
#===============================================================

installation_log "Installing dotfiles..."

# Symlink configuration files located directly in home directory
for file in $files_to_symlink; do
  symlink_file_to_home_dir $file
done

# Symlink fallback files
for fallback_file in $fallback_files_to_symlink; do
  symlink_fallback_file_to_home_dir $fallback_file
done

# Symlink configuration directories to config directory
for dir in $dirs_to_symlink; do
  symlink_directory_to_config_dir $dir
done

# Create local profile file if exist
touch $HOME/.local_profile

###### .config directory links #####
# Install Neovim config
# Create directory for neovim config
# TODO
installation_log "Linking init.vim"
mkdir -p $HOME/.config/nvim/
ln -sf $DOTFILES_DIR/vim/init.vim $HOME/.config/nvim/

# Symlink file templates
mkdir -p $HOME/Templates
ln -sf $DOTFILES_DIR/file-templates/* $HOME/Templates/


installation_log "Dotfiles installation complete!"

