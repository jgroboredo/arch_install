#!/bin/bash

echo 'Installing yay'
install_yay


echo 'Installing AUR packages'
install_aur_packages

install_yay() {
    mkdir /foo
    cd /foo
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm 

    cd /
    rm -rf /foo
}

install_aur_packages() {
    mkdir /foo
    export TMPDIR=/foo
    yay -S --noconfirm acpi
    yay -S --noconfirm pamac-aur
    yay -S --noconfirm clipit
    yay -S --noconfirm ttf-font-awesome
    yay -S --noconfirm hamsket-bin
    yay -S --noconfirm polkit-gnome
    yay -S --noconfirm pa-applet-git
    yay -S pavucontrol
    unset TMPDIR
    rm -rf /foo
}





