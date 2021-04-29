#!/bin/bash

url="https://github.com/neovim/neovim/releases/download/nightly/nvim.appimage"

target_path="$HOME/.local/bin"

echo "Creating $target_path"
mkdir -p $target_path

cd $target_path

echo "Downloading NVIM development release"
wget $url
mv nvim.appimage nvim
chmod u+x nvim

echo "Done"
