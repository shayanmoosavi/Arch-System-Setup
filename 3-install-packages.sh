#!/usr/bin/env bash


source utils.sh

install_packages

aur_pkgs=(
    marp-cli
    megacmd-bin
    klogg-bin
    pdf4qt-bin
)

paru -S --needed "${aur_pkgs[@]}"
