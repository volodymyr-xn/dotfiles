#!/usr/bin/env bash

set -euo pipefail

DOTFILES_DIR="$HOME/dotfiles"

mkdir -p /$HOME/.programing_languages/go/bin
mkdir -p /$HOME/.programing_languages/rust/cargo/bin

symlink_files_from_dir() {
  target=$1

  for file in $target/*; do
    target_file_full_path=$(readlink -f "$file")
    target_file_basename=$(basename "$file")

    ln -nsf "$target_file_full_path" "$destination/$target_file_basename"
  done
}

installation_log() {
  local fmt="$1"; shift
  # shellcheck disable=SC2059
  printf "\n✨ \e[32m(Dotfiles) $fmt" "$@"
}

symlink_to() {
  target=$1
  destination=$2

  installation_log "Linking $target to $destination"

  ln -nfs "$target" "$destination"
}

symlink_file_to_home_dir() {
  symlink_to "$DOTFILES_DIR/$1" "$HOME/.$1"
}

symlink_fallback_file_to_home_dir() {
  file_basename=$(basename $1)
  symlink_to "$DOTFILES_DIR/$1" "$HOME/.$file_basename"
}

symlink_config_directory_to_config_dir() {
  symlink_to "$DOTFILES_DIR/config/$1" "$HOME/.config/$1"
}

#===============================================================
#================= Configuration ===============================
#===============================================================

set -e # Terminate script if anything exits with a non-zero value
set -u # Prevent unset variables

files_to_symlink="\
  profile zprofile bash_profile ackrc asdfrc ctags gemrc \
  gitconfig gitignore_global gitmessage npmrc zshrc \
  inputrc default-gems asdfrc bashrc editorconfig \
  config.reek stylelint"

dirs_to_symlink_to_xdg_config="\
  nvim vim tmux"

config_dirs_to_symlink_to_xdg_config="\
 fish bundle nvim vim tmux rubocop pry htop ghostty mise kitty"

# dirs_to_symlink_to_xdg_config_linux_only="\
#   pipewire wireplumber kitty rofi"
dirs_to_symlink_to_xdg_config_linux_only="\
  pipewire"

# fallback_files_to_symlink="rubocop/rubocop.yml tmux/tmux.conf"
# fallback_files_to_symlink="tmux/tmux.conf"

#===============================================================
#================= Instalation =================================
#===============================================================

installation_log "Installing dotfiles..."

# Install font config
mkdir -p $HOME/.config/fontconfig/conf.d/

ln -nsf $HOME/dotfiles/config/fontconfig/conf.d/local.conf $HOME/.config/fontconfig/conf.d/local.conf
ln -nsf $HOME/dotfiles/config/fontconfig/fonts.conf $HOME/.config/fontconfig/fonts.conf

# Symlink configuration files located directly in home directory
for file in $files_to_symlink; do
  symlink_file_to_home_dir $file
done


# # Symlink fallback files
# for fallback_file in $fallback_files_to_symlink; do
#   symlink_fallback_file_to_home_dir $fallback_file
# done

for dir in $config_dirs_to_symlink_to_xdg_config; do
  symlink_config_directory_to_config_dir "$dir"
done

for dir in $dirs_to_symlink_to_xdg_config; do
  symlink_to "$DOTFILES_DIR/$dir" "$HOME/.config/$dir"
done

# Symlink configuration directories to config directory
for dir in $dirs_to_symlink_to_xdg_config_linux_only; do
  symlink_config_directory_to_config_dir $dir
done

if [[  c-is-mac == 'true' ]]; then
  echo "Setup alacritty for mac"
  ln -nsf $HOME/dotfiles/alacritty_mac $HOME/.config/alacritty
else
  echo "Setup alacritty for linux"
  ln -nsf $HOME/dotfiles/alacritty_linux $HOME/.config/alacritty
fi

installation_log "-> Linking $HOME/gitignore_global to $HOME/.gitignore"
ln -nsf "$HOME/.gitignore_global" "$HOME/.gitignore"

ln -nsf \
  "$HOME/dotfiles/oh-my-zsh-themes/avit_custom.zsh-theme" \
  "$HOME/.oh-my-zsh/custom/themes/"


# Create local_profile file
local_shell_profile_path="$HOME/.local_profile"
installation_log "Create local shell profile file $local_shell_profile_path"
touch $local_shell_profile_path

# Symlink file templates
file_templates_destination="$HOME/Templates/"
installation_log "Symlink file templates to $file_templates_destination"
mkdir -p "$HOME/Templates"

ln -nsf "$DOTFILES_DIR/file-templates/*" "$file_templates_destination"

# symlink_files_from_dir "$DOTFILES_DIR/file-templates/"

echo ''
echo "✨✨✨Dotfiles installation complete!🍰✨✨✨"

# zsh
# source "$HOME/.zshrc"
exec zsh

