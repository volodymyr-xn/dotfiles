#!/usr/bin/env bash

go get -u -v github.com/ncw/rclone

mv ${GOPATH}/bin/rclone $HOME/.local/bin/rclone
