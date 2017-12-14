sudo apt-get install ctags
gem install gem-ctags
gem ctags

mkdir -p ~/.rbenv/plugins
git clone git://github.com/tpope/rbenv-ctags.git \
    ~/.rbenv/plugins/rbenv-ctags
rbenv ctags
