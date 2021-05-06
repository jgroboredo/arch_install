#!/bin/bash

# == Cleanup ==

if [ -n "$ARCH_SWAP" ]; then
    info 'Turning off swap'
    swapoff /mnt/swap/swapfile
fi

set -euo pipefail

if [ ! -f '/mnt/arch_install/success' ]; then
    fail 'Something failed inside the chroot'
fi

sync

echo
printline '-'

info 'Umounting /mnt recursively'
umount -R /mnt
printline '-'
