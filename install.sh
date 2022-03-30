#!/bin/bash

configDir=$HOME/.config/nvim
kittyDir=$HOME/.config/kitty
warpdDir=$HOME/.config/warpd
scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# create the nvim directory
mkdir -p $configDir $kittyDir $warpdDir

# if there any existing configs, save them
mv $configDir/init.vim $configDir/init.vim.old
mv $configDir/init.lua $configDir/init.lua.old
mv $configDir/lua $configDir/lua.old
mv $configDir/coc-settings.json $configDir/coc-settings.json.old
mv $kittyDir/kitty.conf $kittyDir/kitty.conf.old
mv $warpdDir/config $warpdDir/config.old

# copy over the new configs
# ln -s $scriptDir/init.vim $configDir/init.vim
ln -s $scriptDir/lua $configDir/lua
ln -s $scriptDir/init.lua $configDir/init.lua
ln -s $scriptDir/coc-settings.json $configDir/coc-settings.json
ln -s $scriptDir/kitty.conf $kittyDir/kitty.conf
ln -s $scriptDir/warpd $warpdDir/config

echo "Done"
