#!/bin/bash

function check_num_of_args {
    expected=$1
    actual=$2
    if [[ $actual -lt $expected ]]; then
        printf "Expected to receive $expected arguments, but got $actual\n"
        return 1
    fi
    return 0
}

function run_inside_directory {
    check_num_of_args 2 $#
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    dir_path=$1
    shift

    curr_dir=$(pwd)
    cd $dir_path

    # invoke callback
    $@

    cd $curr_dir
}

function save_old_config {
    check_num_of_args 1 $#
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    file_path=$1

    if [[ ! -e "$file_path" ]]; then
        printf "WARN: Skipping $file_path has to point to a file or a directory\n"
        return 1
    fi

    mv "$file_path" "$file_path.old"
    return 0
}
function link_config {
    check_num_of_args 2 $#
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    source_path=$1
    dest_path=$2

    if [[ ! -e "$source_path" ]]; then
        printf "WARN: Skipping $source_path has to point to a file or a directory\n"
        return 1
    fi

    ln -s "$source_path" "$dest_path"
}

configDir=$HOME/.config/nvim
kittyDir=$HOME/.config/kitty
warpdDir=$HOME/.config/warpd
scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# create the nvim directory
mkdir -p $configDir

all_configs=("$configDir/init.vim" "$configDir/init.lua" "$configDir/lua" "$configDir/coc-settings.json" "$kittyDir" "$warpdDir")

for path in ${all_configs[@]}; do
    save_old_config $path
done

for path in ${all_configs[@]}; do
    source_path=$(basename $path)
    link_config "$scriptDir/$source_path" $path
done

echo "Done"
