#!/usr/bin/env bash

installation_log() {
  local fmt="$1"; shift
  # shellcheck disable=SC2059
  printf "\n✨ \e[32m(Dotfiles) $fmt\n" "$@"
}

# backup_file() {
#   # If file alreay present - backup it
#   if [ -f $HOME/.$1 ]; then
#     installation_log ".$1 already present. Backing up..."
#
#     cp $HOME/.$1 "$HOME/.${1}_backup"
#
#     rm -f $HOME/.$1
#   fi
# }


symlink_file() {
  installation_log "-> Linking $DOTFILES_DIR/$1 to $HOME/.$1..."

  ln -nfs "$DOTFILES_DIR/$1" "$HOME/.$1"
}

setup_settings_file() {
  # backup_file $1
  symlink_file $1
}


#===============================================================
#================= Configuration ===============================
#===============================================================

set -e # Terminate script if anything exits with a non-zero value
set -u # Prevent unset variables

files_to_symlink="\
      vim tmux zsh ackrc asdfrc ctags gemrc \
      gitconfig gitignore_global gitmessage npmrc zshrc \
      inputrc pryrc default-gems asdfrc bashrc editorconfig \
      rubocop.yml eslintrc.js config.reek stylelint"

DOTFILES_DIR=$HOME/dotfiles

#===============================================================
#================= Instalation =================================
#===============================================================

installation_log "Installing dotfiles..."

# Symlink configuration files located directly in home directory
for file in $files_to_symlink; do
  setup_settings_file $file
done

# Create local profile file if exist
touch $HOME/.local_profile

# Copy Tmux config
installation_log "Linking .tmux.conf"
ln -sf $DOTFILES_DIR/tmux/tmux.conf $HOME/.tmux.conf

# Link Alacrity config
installation_log "Linking alacritty.yml"
mkdir -p $HOME/.config/alacritty/
ln -sf $DOTFILES_DIR/alacritty.yml $HOME/.config/alacritty/

installation_log "Linking kitty.conf"
mkdir -p $HOME/.config/kitty/
ln -sf $DOTFILES_DIR/kitty.conf $HOME/.config/kitty/

installation_log "Linking Rofi config dir"
ln -sf $DOTFILES_DIR/rofi $HOME/.config/rofi

installation_log "Linking Rubocop config dir"
ln -sf $DOTFILES_DIR/rubocop $HOME/.config/rubocop

# Install Neovim config
# Create directory for neovim config
installation_log "Linking init.vim"
mkdir -p $HOME/.config/nvim/
ln -sf $DOTFILES_DIR/vim/init.vim $HOME/.config/nvim/

installation_log "Linking htop config"
mkdir -p $HOME/.config/htop/
ln -sf $DOTFILES_DIR/htop/htoprc $HOME/.config/htop/

# Symlink file templates
mkdir -p $HOME/Templates
ln -sf $DOTFILES_DIR/file-templates/gnome/* $HOME/Templates/

installation_log "Dotfiles installation complete!"
