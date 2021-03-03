#!/bin/bash

configDir=$HOME/.config/nvim
scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# create the nvim directory
mkdir -p $configDir

# if there any existing configs, save them
mv $configDir/init.vim $configDir/init.vim.old
mv $configDir/coc-settings.json $configDir/coc-settings.json.old

# copy over the new configs
ln -s $scriptDir/init.vim $configDir/init.vim
ln -s $scriptDir/coc-settings.json $configDir/coc-settings.json

echo "Done"
