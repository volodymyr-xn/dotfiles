#!/usr/bin/env sh

dotfiles_echo() {
  local fmt="$1"; shift
  # shellcheck disable=SC2059
  printf "\n[DOTFILES] $fmt\n" "$@"
}


set -e # Terminate script if anything exits with a non-zero value
set -u # Prevent unset variables

files="vim tmux zsh ackrc asdfrc config.reek gemrc gitconfig gitignore_global gitmessage npmrc zshrc inputrc"
DOTFILES_DIR=$HOME/dotfiles

dotfiles_echo "Installing dotfiles..."

for file in $files; do
  if [ -f $HOME/.$file ]; then
    dotfiles_echo ".$file already present. Backing up..."
    cp $HOME/.$file "$HOME/.${file}_backup"
    rm -f $HOME/.$file
  fi
  dotfiles_echo "-> Linking $DOTFILES_DIR/$file to $HOME/.$file..."
  ln -nfs "$DOTFILES_DIR/$file" "$HOME/.$file"
done

if [ -f $HOME/.tmux.conf ]; then
  dotfiles_echo ".tmux.conf already present. Backing up..."
  cp $HOME/.tmux.conf "$HOME/.tmux_conf_backup"
  rm -f $HOME/.tmux.conf
fi

ln -s ~/dotfiles/tmux/tmux.conf ~/.tmux.conf
ln -s ~/dotfiles/vim/ ~/.config/nvim/

git submodule update --init --recursive

touch ~/.user_settings
mkdir ~/bin

# ./fonts/install.sh
instalation_scripts/install_fzf.sh
instalation_scripts/install_silver_searcher.sh
instalation_scripts/install_oh-my-zsh.sh
instalation_scripts/install_ctags.sh

dotfiles_echo "Dotfiles installation complete!"
