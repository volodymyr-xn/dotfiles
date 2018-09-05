# dependencies
sudo apt-get install python-gi-dev libgirepository1.0-dev automake libtool swig gtk-doc-tools

timestamp=$(date +%s)
destination_dir=/tmp/libvips-$timestamp

git clone https://github.com/jcupitt/libvips.git $destination_dir
cd $destination_dir
./autogen.sh
make
sudo make install -j 4
