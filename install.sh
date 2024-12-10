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

    if [[ ! -d  "$dir_path" ]]; then
        printf "WARN: Skipping $dir_path has to point to a directory\n"
        return 1
    fi

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

    # echo $source_path $dest_path

    if [[ ! -e "$source_path" ]]; then
        printf "WARN: Skipping $source_path has to point to a file or a directory\n"
        return 1
    fi

    # make sure that there is already no older files backed up previously
    if [[ -e "$dest_path" ]] && [[ ! -e "$dest_path.old" ]]; then
        printf "INFO: Backing up old $dest_path\n"
        mv "$dest_path" "$dest_path.old"
        # echo "mv \"$dest_path\" \"$dest_path.old\""
    fi

    if [[ ! -e "$dest_path" ]]; then
        ln -s "$source_path" "$dest_path"
    else
        printf "ERROR: Not going to link $source_path because $dest_path already exists"
    fi
}

function install_jdtls {
    printf "INFO: Cloning jdtls\n"
    rm -rf "jdtls-launcher"
    git clone "https://github.com/dsych/jdtls-launcher.git"

    cd "jdtls-launcher"
    install_location="$(pwd)/jdtls-launcher.sh"
    link_location="$HOME/.local/bin/jdtls"

    printf "INFO: Creating symlink at ${link_location}\n"
    chmod -R 755 "$install_location"
    rm "$link_location" 2> /dev/null
    ln -s "$install_location" "$link_location"

    printf "INFO: Installing jdtls dependencies\n"
    jdtls --install
}

function install_java_debug {
    printf "INFO: Cloning java-debug\n"
    rm -rf "java-debug"
    git clone "https://github.com/microsoft/java-debug.git"

    mvn -f "$(pwd)/java-debug/pom.xml" clean package
}

function install_java_decompiler {
    printf "INFO: Cloning vscode-java-decompiler\n"
    rm -rf "vscode-java-decompiler"
    git clone "https://github.com/dgileadi/vscode-java-decompiler.git"
}

function install_lombok {
    printf "INFO: Downloading lombok\n"
    wget "https://projectlombok.org/downloads/lombok.jar"
}

function install_checkstyle {
    printf "INFO: Downloading checkstyle\n"
    wget "https://github.com/checkstyle/checkstyle/releases/download/checkstyle-10.5.0/checkstyle-10.5.0-all.jar" -O checkstyle.jar
}

function install_fzf {
    printf "INFO: Cloning fzf into ~/.fzf directory\n"
    git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
    printf "INFO: Installing fzf"
    ~/.fzf/install

    printf "INFO: Cloning fzf-tab-completion\n"
    git clone "https://github.com/lincheney/fzf-tab-completion.git"
    printf "INFO: add 'source $(pwd)/fzf-tab-completion/zsh/fzf-zsh-completion.sh' to .zshrc"
}

configDir=$HOME/.config/nvim
scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

all_configs=(
    "$configDir/init.lua"
    "$configDir/lua"
    "$configDir/coc-settings.json"
    "$HOME/.config/kitty"
    "$HOME/.config/warpd"
    "$HOME/.config/lsd"
    "$HOME/.config/fd"
    "$HOME/.config/wezterm"
    "$HOME/.config/starship.toml"
)


# create the nvim directory
mkdir -p $configDir

for path in ${all_configs[@]}; do
    save_old_config $path
done

for path in ${all_configs[@]}; do
    source_path=$(basename $path)
    # dest_path=$(dirname $path)
    link_config "$scriptDir/$source_path" "$path"
done

printf "Begin installing dependencies\n"

run_inside_directory "$HOME/.local/source" install_jdtls
run_inside_directory "$HOME/.local/source/jdtls-launcher" install_java_debug
run_inside_directory "$HOME/.local/source/jdtls-launcher" install_java_decompiler
run_inside_directory "$HOME/.local/source/jdtls-launcher" install_lombok
run_inside_directory "$HOME/.local/source/jdtls-launcher" install_checkstyle

which cargo &> /dev/null

if [[ "$?" != "0" ]]; then
    cargo install --locked fd-find
    cargo install --locked starship

    run_inside_directory "$HOME/.local/source" install_fzf

else
    echo "------------------------"
    echo "Also need to install the following manually:"
    echo "- Starship: https://starship.rs/guide/#%F0%9F%9A%80-installation"
    echo "- FZF: https://github.com/junegunn/fzf#installation"
    echo "- FZF tab completion for ZSH: https://github.com/lincheney/fzf-tab-completion#installation"
    echo "----------------------"
fi

printf "Done!!!\n"
