timestamp=$(date +%s)
vim_source_dir=/tmp/vim-$timestamp

echo "Cloning into $vim_source_dir"
git clone https://github.com/vim/vim $vim_source_dir

echo "Stating compile process"
( cd $vim_source_dir && make -j 8 && sudo make install -j 8)

echo "Remove vim source directory $vim_source_dir"
rm -rf $vim_source_dir

