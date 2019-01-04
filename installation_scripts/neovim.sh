# installing dependencies
sudo apt-get install ninja-build gettext libtool libtool-bin autoconf automake cmake g++ pkg-config unzip

timestamp=$(date +%s)
neovim_source_dir=/tmp/neovim-$timestamp

git clone https://github.com/neovim/neovim $neovim_source_dir

echo "Stating compile process"
cd $neovim_source_dir

latest_tag=`git describe --tags $(git rev-list --tags --max-count=1)`

git checkout $latest_tag

rm -r build
make clean
make CMAKE_BUILD_TYPE=Release -j 8
sudo make install -j 8

echo "Remove neovim source directory $neovim"
rm -rf $neovim
