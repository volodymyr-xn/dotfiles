#!/usr/bin/env bash

set -u

thumbnailers_source_dir="$HOME/dotfiles/software_extensions/thumbnailers"
thumbnailers_destination_dir=/usr/share/thumbnailers

# WebM and WebP GDK Pixbuf Loader library ( https://github.com/aruiz/webp-pixbuf-loader)
sudo pacman -S webp-pixbuf-loader

sudo ln -sf "$thumbnailers_source_dir/raw.thumbnailer" "$thumbnailers_destination_dir/raw.thumbnailer"
sudo ln -sf "$thumbnailers_source_dir/psd.thumbnailer" "$thumbnailers_destination_dir/psd.thumbnailer"
sudo ln -sf "$thumbnailers_source_dir/evince.thumbnailer" "$thumbnailers_destination_dir/evince.thumbnailer"
