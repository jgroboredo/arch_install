#!/bin/bash

# == Partition and mount disk ==

# shellcheck disable=SC2153
fdisk -l "/dev/$ARCH_DISK"

pause "Will partition /dev/$ARCH_DISK for $ARCH_BOOT_MODE"

if [ "$ARCH_BOOT_MODE" == 'efi' ]; then
    info "Partitioning /dev/$ARCH_DISK for EFI"
    parted --script "/dev/$ARCH_DISK" \
        mklabel gpt \
        mkpart primary fat32 1MiB 550MiB \
        set 1 esp on \
        mkpart primary btrfs 550MiB 100%
else
    parted --script "/dev/$ARCH_DISK" \
        mklabel msdos \
        mkpart primary btrfs 1MiB 100% \
        set 1 boot on
fi

fdisk -l "/dev/$ARCH_DISK"

pause "Partitioned /dev/$ARCH_DISK"

# == Format partitions ==

ARCH_DISK_P=$ARCH_DISK
if [[ "$ARCH_DISK_P" == nvme* ]]; then
    ARCH_DISK_P="${ARCH_DISK_P}p"
fi

if [ "$ARCH_BOOT_MODE" == 'efi' ]; then
    info "Formatting /dev/${ARCH_DISK_P}1 as FAT32"
    mkfs.vfat -F32 -n "BOOT" "/dev/${ARCH_DISK_P}1"

    ARCH_DISK_ROOT_PART="/dev/${ARCH_DISK_P}2"
else
    ARCH_DISK_ROOT_PART="/dev/${ARCH_DISK_P}1"
fi

if [ "$ARCH_LUKS" == 'yes' ]; then
    info "Encrypting ${ARCH_DISK_ROOT_PART}"
    echo "$ARCH_LUKS_PASSWORD" | cryptsetup -y -v luksFormat "${ARCH_DISK_ROOT_PART}" --key-file -

    info "Mounting ${ARCH_DISK_ROOT_PART} to cryptroot"
    echo "$ARCH_LUKS_PASSWORD" | cryptsetup open "${ARCH_DISK_ROOT_PART}" cryptroot --key-file -

    ARCH_DISK_ROOT_PART="/dev/mapper/cryptroot"
fi

info "Formatting ${ARCH_DISK_ROOT_PART} as btrfs"
mkfs.btrfs -f -L "Arch Linux" "${ARCH_DISK_ROOT_PART}"

# == Create btrfs subvolumes ==

info "Creating btrfs subvolumes"

mount -t btrfs -o noatime "${ARCH_DISK_ROOT_PART}" /mnt

btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@var
btrfs subvolume create /mnt/@swap
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@storage

umount -R /mnt

# == Mount everything ==

info "Mounting partitions"

mount -t btrfs -o noatime,x-mount.mkdir,subvol=/@,noatime  "${ARCH_DISK_ROOT_PART}" /mnt
mount -t btrfs -o noatime,x-mount.mkdir,subvol=/@home      "${ARCH_DISK_ROOT_PART}" /mnt/home
mount -t btrfs -o noatime,x-mount.mkdir,subvol=/@var       "${ARCH_DISK_ROOT_PART}" /mnt/var
mount -t btrfs -o noatime,x-mount.mkdir,subvol=/@swap      "${ARCH_DISK_ROOT_PART}" /mnt/swap
mount -t btrfs -o noatime,x-mount.mkdir,subvol=/@snapshots "${ARCH_DISK_ROOT_PART}" /mnt/.snapshots

mkdir -p /mnt/mnt
mount -t btrfs -o noatime,x-mount.mkdir,subvol=/@storage   "${ARCH_DISK_ROOT_PART}" /mnt/mnt/storage
btrfs property set /mnt/mnt/storage compression zstd:2
chown -c "$ARCH_ADMIN_UID:$ARCH_ADMIN_UID" /mnt/mnt/storage

if [ "$ARCH_BOOT_MODE" == 'efi' ]; then
    mkdir -p /mnt/efi
    mount "/dev/${ARCH_DISK_P}1" /mnt/efi
fi
