#!/usr/bin/env bash

set -u


source_udev_rules_dir="$HOME/dotfiles/udev_rules"
destination_udev_rules_dir="/etc/udev/rules.d"

files_to_symlink="$source_udev_rules_dir/*"

for file in $files_to_symlink
do
  target_file_full_path=$(readlink -f "$file")
  target_file_basename=$(basename "$file")

  echo "Processing and symlinking '$target_file_basename' udev rule file..."

  # You can test udev rules for camera with `sudo udevadm test /dev/video4`
  sudo ln -nsf "$target_file_full_path" "$destination_udev_rules_dir/$target_file_basename"
done
