#!/bin/bash

configDir=$HOME/.config/nvim
kittyDir=$HOME/.config/kitty
scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# create the nvim directory
mkdir -p $configDir $kittyDir

# if there any existing configs, save them
mv $configDir/init.vim $configDir/init.vim.old
mv $configDir/coc-settings.json $configDir/coc-settings.json.old
mv $kittyDir/kitty.conf $kittyDir/kitty.conf.old

# copy over the new configs
ln -s $scriptDir/init.vim $configDir/init.vim
ln -s $scriptDir/coc-settings.json $configDir/coc-settings.json
ln -s $scriptDir/kitty.conf $kittyDir/kitty.conf

echo "Done"
