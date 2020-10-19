#!/bin/bash

configDir=$HOME/.config/nvim

# create the nvim directory
mkdir -p $configDir

# if there any existing configs, save them
mv $configDir/init.nvim $configDir/init.nvim.old
mv $configDir/coc-settings.json $configDir/coc-settings.json.old

# copy over the new configs
cp ./init.vim ./coc-settings.json $configDir

echo "Done"
