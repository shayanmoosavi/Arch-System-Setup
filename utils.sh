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
    # Use find to safely get files, then use while read to process line by line
    while IFS= read -r -d $'\0' file; do

        printf "Read file %s\n" "$file"
        printf "Checking if the packages are already installed\n"

        # Read packages line by line from the file
        while IFS= read -r pkg; do

            # Strip leading/trailing whitespace and skip if line is empty or starts with #
            pkg=$(echo "$pkg" | xargs)

            if [[ -z "$pkg" || "$pkg" =~ ^# ]]; then
                continue
            fi

            if ! is_installed "$pkg"; then
                # Adding the packages which are not installed
                packages+=("$pkg")
            fi
        done < "$file"
    done < <(find "$pkg_dir" -type f -print0)

    # Installing the packages
    if [ ${#packages[@]} -ne 0 ]; then
        echo "Installing: ${packages[*]}"
        sudo pacman -S --needed --noconfirm "${packages[@]}"
    fi
}
