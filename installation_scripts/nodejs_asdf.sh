asdf plugin-add nodejs https://github.com/asdf-vm/asdf-nodejs.git

bash ~/.asdf/plugins/nodejs/bin/import-release-team-keyring

last_node_version=$(asdf list-all nodejs | tail -n 1)
asdf install nodejs $last_node_version
asdf global nodejs $last_node_version

npm i yarn -g
