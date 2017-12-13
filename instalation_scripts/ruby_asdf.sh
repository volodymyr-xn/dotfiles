asdf plugin-add ruby https://github.com/asdf-vm/asdf-ruby.git

last_ruby_version=$(asdf list-all ruby | tail -n 1)

old_ruby_version=$(asdf list ruby | head -n 1)
echo "Remove old ruby version $old_ruby_version"
asdf uninstall ruby $old_ruby_version

echo "Install ruby $last_ruby_version"
asdf install ruby $last_ruby_version
asdf global ruby $last_ruby_version
