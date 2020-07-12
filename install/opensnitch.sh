#!/usr/bin/env bash

# install dependencies
sudo apt-get install git libnetfilter-queue-dev libpcap-dev protobuf-compiler python3-pip
go get github.com/golang/protobuf/protoc-gen-go
go get -u github.com/golang/dep/cmd/dep
cd $GOPATH/src/github.com/golang/dep
./install.sh
export PATH=$PATH:$GOPATH/bin
python3 -m pip install --user grpcio-tools
# clone the repository (ignore the message about no Go files being found)
go get github.com/gustavo-iniguez-goya/opensnitch
cd $GOPATH/src/github.com/gustavo-iniguez-goya/opensnitch
# compile && install
# cd daemon
# make
# sudo make install
# cd -
# cd ui
# sudo pip3 install -r requirements.txt

git checkout v1.0.0rc10
make
sudo make install
# # enable opensnitchd as a systemd service and start the UI
sudo systemctl enable opensnitchd
sudo service opensnitchd start
opensnitch-ui
