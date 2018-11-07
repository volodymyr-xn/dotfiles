atom_deb_file_path=/tmp/atom_beta_linux.deb

wget https://atom.io/download/deb\?channel\=beta -O $atom_deb_file_path

sudo dpkg -i $atom_deb_file_path
rm $atom_deb_file_path
