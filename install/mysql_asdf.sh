asdf plugin-add mysql

$mysql_version=$1

if [ -z "$mysql_version"]
then
  $mysql_version=$(asdf list-all mysql)
fi

asdf install mysql $mysql_version
asdf global postgres $postgres_version
