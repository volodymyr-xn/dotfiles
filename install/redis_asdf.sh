asdf plugin-add redis https://github.com/smashedtoatoms/asdf-redis.git

redis_version=$1

if [ -z "$redis_version"]
then
  # if version is not specified take the latest redis version
  redis_version=$(asdf list-all redis | tail -n 1)
fi

asdf install redis $redis_version
asdf global redis $redis_version
