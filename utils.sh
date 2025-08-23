#!/usr/bin/env bash

pkg_dir=./packages

# Function to check whether a package is installed
is_installed() {
    pacman -Qi "$1" &> /dev/null
}

# Function to install packages
install_packages() {

    # List of packages to install
    local packages=()
    
    printf "Reading packages list...\n"
    for file in $pkg_dir/*; do

        # Reading the packages from the files
        mapfile -t pkgs < $file

        printf "Read file $file\n"
        printf "Checking if the packages are already installed\n"
        for pkg in ${pkgs[@]}; do
            if ! is_installed $pkg; then

                # Adding the packages which are not installed
                packages+=($pkg)
            fi
        done
    done
   
    # Installing the packages
    if [ ${#packages[@]} -ne 0 ]; then
        echo "Installing: ${packages[*]}"
        sudo pacman -S --needed "${packages[@]}"
    fi
} 

