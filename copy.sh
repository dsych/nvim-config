#!/bin/bash

configDir=$HOME/.config/nvim

git update-index --refresh | wc -l | grep "^0$" &> /dev/null

# make sure that there are no outstanding changes in the current repo
if [ $? -ne 0 ]
then
        echo "There are outstanding changes. Commit them first."
        exit 1
fi

# copy new versions of the configs
cp $configDir/init.vim $configDir/coc-settings.json .

