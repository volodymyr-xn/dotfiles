asdf plugin-add ruby https://github.com/asdf-vm/asdf-ruby.git

last_ruby_version=$(asdf list-all ruby | tail -n 1)

echo "Install ruby $last_ruby_version"
asdf install ruby $last_ruby_version
asdf global ruby $last_ruby_version

gem install bundler
gem install tmuxinator
gem install rb-readline
asdf reshim ruby
