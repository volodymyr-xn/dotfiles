# install dependencies
sudo apt-get install -y automake build-essential pkg-config libevent-dev libncurses5-dev

timestamp=$(date +%s)
tmux_source_dir=/tmp/tmux-$timestamp

git clone https://github.com/tmux/tmux.git $tmux_source_dir

cd $tmux_source_dir

# checkout to last stable version
git checkout 2.6

sh autogen.sh
./configure && make -j 4
sudo make install
cd -

rm -rf $tmux_source_dir
