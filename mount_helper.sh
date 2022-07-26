#!/bin/bash

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 disk label" >&2
  exit 1
fi

ARCH_DISK="$1"

ARCH_CHROOT=".chroot"
ARCH_DISK_ROOT_PART="$ARCH_DISK""2"
ARCH_DISK_EFI_PART="$ARCH_DISK""1"

mkdir "$ARCH_CHROOT"

mount -t btrfs -o noatime,x-mount.mkdir,compress=zstd,subvol=/@          "$ARCH_DISK_ROOT_PART" "$ARCH_CHROOT"
mount -t btrfs -o noatime,x-mount.mkdir,compress=zstd,subvol=/@home      "$ARCH_DISK_ROOT_PART" "$ARCH_CHROOT/home"
mount -t btrfs -o noatime,x-mount.mkdir,compress=zstd                    "$ARCH_DISK_ROOT_PART" "$ARCH_CHROOT/mnt/root"
mount -t btrfs -o noatime,x-mount.mkdir,compress=zstd,subvol=/@storage   "$ARCH_DISK_ROOT_PART" "$ARCH_CHROOT/mnt/storage"
mount -t btrfs -o noatime,x-mount.mkdir,compress=zstd,subvol=/@swap      "$ARCH_DISK_ROOT_PART" "$ARCH_CHROOT/swap"
mount -t btrfs -o noatime,x-mount.mkdir,compress=zstd,subvol=/@var_log   "$ARCH_DISK_ROOT_PART" "$ARCH_CHROOT/var/log"
mount -t btrfs -o noatime,x-mount.mkdir,compress=zstd,subvol=/@var_cache "$ARCH_DISK_ROOT_PART" "$ARCH_CHROOT/var/cache"
mount -t btrfs -o noatime,x-mount.mkdir,compress=zstd,subvol=/@recovery  "$ARCH_DISK_ROOT_PART" "$ARCH_CHROOT/recovery"

mkdir -p "$ARCH_CHROOT/efi"
mount "$ARCH_DISK_EFI_PART" "$ARCH_CHROOT/efi"


