#!/bin/bash

# shellcheck disable=SC2153
ARCH_DISK_P=$ARCH_DISK
if [[ "$ARCH_DISK_P" == nvme* ]]; then
    ARCH_DISK_P="${ARCH_DISK_P}p"
fi

# == Boot ==

KERNEL_OPTS='ipv6.disable=1 snd_hda_intel.power_save=0'

if [ "$(command -v apparmor_status)" ]; then
    KERNEL_OPTS="apparmor=1 lsm=lockdown,yama,apparmor,bpf $KERNEL_OPTS"
fi

if [ "$ARCH_BOOT_MODE" == 'efi' ]; then
    info "Setting up systemd-boot"

    bootctl --path=/efi install
    cat > /efi/loader/loader.conf <<EOF
timeout 0
editor no
auto-entries 1
auto-firmware 1
console-mode keep
EOF

    if [ "$ARCH_LUKS" == 'yes' ]; then
        info "Setting up auto LUKS unlock"

        dd bs=512 count=4 if=/dev/urandom of=/efi/helloworld iflag=fullblock
        echo "$ARCH_LUKS_PASSWORD" | cryptsetup luksAddKey "/dev/${ARCH_DISK_P}2" /efi/helloworld --key-file -

        sed -i 's/^MODULES=.*/MODULES=(vfat)/' /etc/mkinitcpio.conf
        sed -i -E 's/(^HOOKS=.*)/#\1\nHOOKS=(base udev autodetect keyboard keymap modconf block encrypt filesystems fsck)/' /etc/mkinitcpio.conf
        mkinitcpio -p "$ARCH_KERNEL"
    fi

    if [ "$ARCH_LUKS" == 'yes' ]; then
        ROOT_OPTS="cryptdevice=UUID=$(blkid -o value -s UUID /dev/${ARCH_DISK_P}2):cryptroot cryptkey=/dev/disk/by-uuid/$(blkid -o value -s UUID /dev/${ARCH_DISK_P}1):vfat:/helloworld root=/dev/mapper/cryptroot"
    else
        ROOT_OPTS="root=UUID=$(blkid -o value -s UUID /dev/${ARCH_DISK_P}2)"
    fi

    echo "${ROOT_OPTS} rootflags=subvol=/@ rw ${KERNEL_OPTS}" > /boot/cmdline.txt

    mkdir -p /efi/EFI/systemd
    cp /usr/lib/systemd/boot/efi/systemd-bootx64.efi /efi/EFI/systemd/systemd-bootx64.efi

    unified-kernel-image

    efibootmgr --create \
        --disk "/dev/$ARCH_DISK" \
        --part "1" \
        --label "systemd-boot" \
        --loader "EFI\\systemd\\systemd-bootx64.efi" \
        --verbose
else
    if [ "$ARCH_LUKS" == 'yes' ]; then
        fail 'Luks on BIOS not implemented'
    fi

    if [ "$(command -v grub-install)" ]; then
        info "Setting up grub"

        sed -i "s/ quiet/$KERNEL_OPTS/" /etc/default/grub
        grub-install --target=i386-pc "/dev/$ARCH_DISK_P"
        grub-mkconfig -o /boot/grub/grub.cfg
    #elif [ -f "/usr/lib/syslinux/bios/mbr.bin" ]; then
    #    mkdir -p /boot/syslinux
    #    cp /usr/lib/syslinux/bios/*.c32 /boot/syslinux/
    #    extlinux --install /boot/syslinux
    #    dd bs=440 count=1 conv=notrunc if="/usr/lib/syslinux/bios/mbr.bin" of="/dev/${ARCH_DISK_P}"
    else
        fail "No compatible bootloader installed for bios"
    fi
fi
