#!/bin/bash

# ----------------------------------------------------------------------------
# packages

packages=(
    zsh
    git
    openssh
    rsync
    rclone
    wol
    exa
    man
    neovim
)

pkgs_cmd=""

for p in "${packages[@]}"; do
    pkgs_cmd+=" $p"
done

pkg upgrade
pkg upgrade

# shellcheck disable=SC2086
pkg install $pkgs_cmd

# ----------------------------------------------------------------------------
# shell

mkdir -p ~/.local/share/
mkdir -p ~/.config/

echo '' > "$PREFIX/etc/motd"

# p10k
git clone git@github.com:romkatv/powerlevel10k.git ~/.local/share/powerlevel10k

chsh -s zsh

rm -f ~/.zshenv
ln -s ~/workspace/dotfiles/config/zsh/.zshenv ~/.zshenv

rm -rf ~/.config/zsh
ln -s ~/workspace/dotfiles/config/zsh/ ~/.config/zsh

rm -rf ~/.config/git
ln -s ~/workspace/dotfiles/config/git/ ~/.config/git

rm -f ~/.ssh/config
ln -s ~/workspace/dotfiles/config/ssh/config ~/.ssh/config
