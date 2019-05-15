#!/usr/bin/env bash

# git clone https://github.com/ncw/rclone.git
# cd rclone
# go build

go get -u -v github.com/ncw/rclone

mv ${GOPATH}/bin/rclone $HOME/.local/bin/rclone
