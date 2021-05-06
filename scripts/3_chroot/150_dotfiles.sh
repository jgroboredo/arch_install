#!/bin/bash

# == preconfigured dotfiles ==

printline '='

# TODO use skel?
rm -f /etc/skel/.bash*

# deploy dotfiles
RSYNC_CMD='rsync --inplace --recursive --copy-links --perms --times'

$RSYNC_CMD "$ROOT_DIR/files/root/" "/"
$RSYNC_CMD "$ROOT_DIR/files/home/" "/home/$ARCH_USER"
chown -R "$ARCH_USER:$ARCH_USER" "/home/$ARCH_USER"
if [ "$ARCH_USER" != "$ARCH_ADMIN" ]; then
    $RSYNC_CMD "$ROOT_DIR/files/home/" "/home/$ARCH_ADMIN"
    chown -R "$ARCH_ADMIN:$ARCH_ADMIN" "/home/$ARCH_ADMIN"
fi

if [ "$ARCH_GPU_TYPE" != 'optimus' ]; then
    rm -f /etc/X11/xorg.conf.d/10-nvidia-prime.conf

    if [ "$ARCH_GPU_TYPE" != 'intel' ]; then
        rm -f /etc/X11/xorg.conf.d/20-intel.conf
    fi
fi

if [ "$ARCH_GPU_TYPE" != 'amd' ]; then
    rm -f /etc/X11/xorg.conf.d/20-amdgpu.conf
fi

# fonts, from https://gist.github.com/cryzed/e002e7057435f02cc7894b9e748c5671
if [ -d /etc/fonts ]; then
    ln -sf /etc/fonts/conf.avail/11-lcdfilter-default.conf /etc/fonts/conf.d
    ln -sf /etc/fonts/conf.avail/10-sub-pixel-rgb.conf /etc/fonts/conf.d
fi

# Fix sudoers permission
chmod -c 750 "/etc/sudoers.d"
chmod -c 0440 "/etc/sudoers.d/secure"

# architecture-specific changes
if [ "$ARCH_CPU_BRAND" = 'armv7' ] || [ "$ARCH_CPU_BRAND" = 'aarch64' ]; then
    rm -f /etc/sddm.conf.d/jose.conf

    mv /etc/pacman.d/mirrorlist-arm /etc/pacman.d/mirrorlist
    rm -f /etc/pacman.d/mirrorlist-x86
elif [ "$ARCH_CPU_BRAND" == 'intel' ] || [ "$ARCH_CPU_BRAND" == 'amd' ]; then
    rm -f /etc/modules-load.d/w1.conf

    mv /etc/pacman.d/mirrorlist-x86 /etc/pacman.d/mirrorlist
    rm -f /etc/pacman.d/mirrorlist-arm
else
    fail "I don't know what to do with '$ARCH_CPU_BRAND'"
fi

# https://www.reddit.com/r/openSUSE/comments/jtnwzj/os_taking_some_time_to_shutdown_completely_a_stop/
echo 'NO_AT_BRIDGE=1' >> /etc/environment
