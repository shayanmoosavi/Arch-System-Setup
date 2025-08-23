#!/usr/bin/env bash


source utils.sh

install_packages

aur_pkgs=(
    marp-cli
    megacmd-bin
    waypaper
)

paru -S --needed "${aur_pkgs[@]}"
