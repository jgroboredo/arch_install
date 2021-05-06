#!/bin/bash

# == linux-ck ==

if [[ "$ARCH_KERNEL" == linux-ck* ]]; then
    {
        echo "[repo-ck]"
        echo "Server = http://repo-ck.com/\$arch"
    } >> /etc/pacman.conf

    pacman-key -r 5EE46C4C
    pacman-key --lsign-key 5EE46C4C
fi

if [ "$(command -v mkinitcpio)" ]; then
    if [ ! -f "/etc/mkinitcpio.d/$ARCH_KERNEL.preset" ]; then
        fail "Kernel $ARCH_KERNL is not installed"
    fi

    sed -i -E "s/PRESETS=.*/PRESETS=('default')/" "/etc/mkinitcpio.d/$ARCH_KERNEL.preset"
    rm -f "/boot/initramfs-$ARCH_KERNEL-fallback.img"
elif [ "$(command -v booster)" ]; then
    info "TODO: Setup booster"
else
    fail "No tool to setup initramfs"
fi
