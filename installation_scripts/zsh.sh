timestamp=$(date +%s)
zsh_source_path=/tmp/zsh-$timestamp

echo 'Download zsh source code to $zsh_source_path'
mkdir -p $zsh_source_path

# Download and unapack zsh source code to tmp directory
curl http://www.zsh.org/pub/zsh.tar.gz | tar -xzvf - -C $zsh_source_path

(cd $zsh_source_path && cd $(ls -d */|head -n 1) && ./configure && make -j 8 && sudo make install)

# Remove tmp directory with source code
rm -rf $zsh_source_path

# Add Zsh to the list of shells in /etc/shells.
which zsh | sudo tee -a /etc/shells

# Set Zsh as the default shell for the current user.
sudo chsh -s $(which zsh)
