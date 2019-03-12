#!/usr/bin/env bash

go get -u -v github.com/ncw/rclone

sudo cp ${GOPATH}bin/rclone /usr/local/bin/rclone
