#!/bin/bash

install_yay() {
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm 
    cd ../
}

install_aur_packages() {
    yay -S --noconfirm acpi
    yay -S --noconfirm pamac-aur
    yay -S --noconfirm clipit
    yay -S --noconfirm ttf-font-awesome
    yay -S --noconfirm hamsket-bin
    yay -S --noconfirm polkit-gnome
    yay -S --noconfirm pa-applet-git
    yay -S --noconfirm pop-gtk-theme-git
    yay -S --noconfirm pop-icon-theme-git
    yay -S --noconfirm vim-plug-git
    yay -S --noconfirm vim-youcompleteme-git
    yay -S --noconfirm visual-studio-code-bin
    yay -S --noconfirm zoom
    yay -S --noconfirm hunspell-pt_pt
    yay -S --noconfirm textext
    yay -S --noconfirm qtgrace
}

echo 'Installing yay'
install_yay


echo 'Installing AUR packages'
install_aur_packages

