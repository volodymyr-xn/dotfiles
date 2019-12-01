destination_dir=$(dotfiles-tempdir-for 'transmission' 'master')

git clone https://github.com/transmission/transmission $destination_dir

cd $destination_dir

git submodule update --init

mkdir build
cd build
cmake ..

make -j $(nproc)

sudo make install
