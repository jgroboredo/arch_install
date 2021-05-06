#!/bin/bash

# == chroot ==

info 'Chrooting into installed system to continue setup...'
printline '-'

cp -r "$ROOT_DIR" /mnt/arch_install

set +euo pipefail
arch-chroot /mnt /arch_install/install.sh chroot
