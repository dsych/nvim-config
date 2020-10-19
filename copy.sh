#!/bin/bash

configDir=$HOME/.config/nvim
# make sure that there are no outstanding changes in the current repo

# copy new versions of the configs
git update-index --refresh | wc -l | grep "^0$" &> /dev/null

if [ $? -ne 0 ] then
        echo "There are outstanding changes. Commit them first."
        exit 1
fi

cp $configDir/init.nvim $configDir/coc-settings.json .

