#!/bin/bash

# == Pacman & pacstrap ==

if [ "$ARCH_CPU_BRAND" == 'intel' ] || [ "$ARCH_CPU_BRAND" == 'amd' ]; then
    cat "$ROOT_DIR/files/root/etc/pacman.d/mirrorlist-x86" > /etc/pacman.d/mirrorlist
else
    cat "$ROOT_DIR/files/root/etc/pacman.d/mirrorlist-arm" > /etc/pacman.d/mirrorlist
fi

# == Pacstrap ==

pause "Before pacstrap"

pacstrap /mnt \
    base base-devel sudo zsh \
    mkinitcpio btrfs-progs \
    "$ARCH_KERNEL" "$ARCH_KERNEL-headers" linux-firmware "${ARCH_CPU_BRAND}-ucode" \
    apparmor \
    reflector
