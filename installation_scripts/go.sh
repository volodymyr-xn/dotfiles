go_binaries_dir=/tmp/go-binaries

mkdir -p $go_binaries_dir

cd $go_binaries_dir
sudo curl -O https://storage.googleapis.com/golang/go1.9.1.linux-amd64.tar.gz

tar -xzvf $(ls | tail -n 1)

mv go ~/.go
cd -
rm -rf $go_binaries_dir
