#!/bin/bash

# == install yay ==


if [ "$ARCH_AUR_HELPER" == 'none' ]; then
    printline '-'
    info "Skipping AUR helper"
    printline '-'
else
    printline '-'
    info "Installing AUR helper '$ARCH_AUR_HELPER'"
    printline '-'

    AUR_HELPER_CLONE_DIR=/home/$ARCH_ADMIN/.cache/arch-install/aur_helper
    su -P "$ARCH_ADMIN" -c "mkdir -p $AUR_HELPER_CLONE_DIR"
    su -P "$ARCH_ADMIN" -c "cd $AUR_HELPER_CLONE_DIR; git clone https://aur.archlinux.org/$ARCH_AUR_HELPER.git"
    su -P "$ARCH_ADMIN" -c "cd $AUR_HELPER_CLONE_DIR/$ARCH_AUR_HELPER; makepkg -s"
    pacman --noconfirm -U "$AUR_HELPER_CLONE_DIR/$ARCH_AUR_HELPER/$ARCH_AUR_HELPER"*.pkg.tar*

    if [ -f "/etc/paru.conf" ]; then
        sed -i 's/^#BottomUp/BottomUp/' /etc/paru.conf
        sed -i 's/^#NewsOnUpgrade/NewsOnUpgrade/' /etc/paru.conf
    fi

    # == install packages from AUR ==

    # shellcheck disable=SC2086
    pkgs_cmd+=" "$(\
        sed '/^#?} core/q' $ROOT_DIR/scripts/1_config/packages_aur.sh | \
        sed 's/ *#.*/ /g' | \
        sed ':a;N;$!ba;s/\n/ /g' \
    )

    # shellcheck disable=SC2086
    pkgs_cmd+=" "$(\
        sed -n "/^#?{ ${ARCH_HOSTNAME}/,/^#?} ${ARCH_HOSTNAME}/p;/^#?} ${ARCH_HOSTNAME}/q" $ROOT_DIR/scripts/1_config/packages_aur.sh | \
        sed 's/ *#.*/ /g' | \
        sed ':a;N;$!ba;s/\n/ /g' \
    )

    # shellcheck disable=SC2086
    warn su -P "$ARCH_ADMIN" -c "$ARCH_AUR_HELPER -S $pkgs_cmd"
fi
