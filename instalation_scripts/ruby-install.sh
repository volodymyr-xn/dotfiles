cd
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
exec $SHELL

git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
exec $SHELL

rbenv install 2.4.1
rbenv global 2.4.1
