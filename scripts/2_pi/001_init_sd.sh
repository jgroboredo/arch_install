#!/bin/bash

set -euo pipefail

if [ -z "$ROOT_DIR" ]; then
    error() { printf "==> ERROR: $@\n"; } >&2
    die() { error "$@"; exit 1; }
fi

# Config -----------------------------------------------------------------------

if [ "$ARCH_CPU_BRAND" = 'armv7' ]; then
    DISTRO_GZ="ArchLinuxARM-rpi-4-latest.tar.gz"
elif [ "$ARCH_CPU_BRAND" = 'aarch64' ]; then
    DISTRO_GZ="ArchLinuxARM-rpi-aarch64-latest.tar.gz"
else
    fail 'Unknown pi arch'
fi

DISTRO_URL=http://os.archlinuxarm.org/os/$DISTRO_GZ

# Pre-checks -------------------------------------------------------------------

requirements=(aria2c mkimage bsdtar parted btrfs genfstab arch-chroot docker)

for cmd in "${requirements[@]}"; do
    [ "$(command -v $cmd)" ] || die "$cmd is not installed"
done

[ "$(id -u)" = "0" ] || die "This command must be run as root"
[ ! -d "arch_root" ] || die "There are leftovers from a previous run"

# Configuration ----------------------------------------------------------------

lsblk

echo ""

read -r -e -p "Boot disk: " -i "/dev/$ARCH_DISK" DISK_BOOT
read -r -e -p "Root disk: " -i "$DISK_BOOT" DISK_ROOT

if [ "$DISK_BOOT" == "$DISK_ROOT" ]; then
    if [[ $DISK_BOOT == /dev/mmcblk* ]]; then
        PART_BOOT="${DISK_BOOT}p1"
        PART_ROOT="${DISK_ROOT}p2"
    else
        PART_BOOT="${DISK_BOOT}1"
        PART_ROOT="${DISK_ROOT}2"
    fi
else
    PART_BOOT="${DISK_BOOT}p1"
    PART_ROOT="${DISK_ROOT}1"
fi

echo ""
echo "Boot partition: $PART_BOOT"
echo "Root partition: $PART_ROOT"

echo ""
read -r -e -p "Press ENTER to continue"

# Setup disk -------------------------------------------------------------------

[ -z "$(mount | grep "$DISK_BOOT")" ] || die "$DISK_BOOT is mounted somewhere"
[ -z "$(mount | grep "$DISK_ROOT")" ] || die "$DISK_ROOT is mounted somewhere"

if [ "$DISK_BOOT" == "$DISK_ROOT" ]; then
    parted --script "$DISK_BOOT" \
        mklabel msdos \
        mkpart primary fat32 1M 200MiB \
        mkpart primary ext4 200MiB 100%
else
    parted --script "$DISK_BOOT" \
        mklabel msdos \
        mkpart primary fat32 1M 200MiB
    parted --script "$DISK_ROOT" \
        mklabel msdos \
        mkpart primary ext4 1M 100%
fi

mkfs.vfat "${PART_BOOT}" -n "PI-BOOT"
mkfs.btrfs -f "${PART_ROOT}" -L "Arch Linux ARM"

# Prepare BTRFS subvolumes
mkdir arch_root
mount -t btrfs -o noatime "${PART_ROOT}" arch_root

btrfs subvolume create arch_root/@
btrfs subvolume create arch_root/@home
btrfs subvolume create arch_root/@var
btrfs subvolume create arch_root/@swap
btrfs subvolume create arch_root/@snapshots
btrfs subvolume create arch_root/@storage

umount -R arch_root

mount -t btrfs -o subvol=/@,noatime "${PART_ROOT}" arch_root
mount -t btrfs -o subvol=/@home,noatime,x-mount.mkdir "${PART_ROOT}" arch_root/home
mount -t btrfs -o subvol=/@var,noatime,x-mount.mkdir "${PART_ROOT}" arch_root/var
mount -t btrfs -o subvol=/@swap,noatime,x-mount.mkdir "${PART_ROOT}" arch_root/swap
mount -t btrfs -o subvol=/@snapshots,noatime,x-mount.mkdir "${PART_ROOT}" arch_root/.snapshots

mkdir -p arch_root/mnt
mount -t btrfs -o subvol=/@storage,noatime,x-mount.mkdir "${PART_ROOT}" arch_root/mnt/storage
chown -c "1995:1995" arch_root/mnt/storage

mkdir -p arch_root/boot
mount "${PART_BOOT}" arch_root/boot

PART_ROOT_UUID=$(blkid -o value -s UUID "${PART_ROOT}")
PART_BOOT_UUID=$(blkid -o value -s UUID "${PART_BOOT}")

# Download distro --------------------------------------------------------------

if [ ! -f "$DISTRO_GZ" ]; then
    aria2c "$DISTRO_URL"
    chown "$(logname):$(logname)" "$DISTRO_GZ"
    chmod 644 "$DISTRO_GZ"
fi

# Install distro ---------------------------------------------------------------

echo ""
echo "Extracting $DISTRO_GZ"

bsdtar -xpf "$DISTRO_GZ" -C arch_root

echo "Syncing"
sync

# Finish btrfs

genfstab -U arch_root > arch_root/etc/fstab
sed -i -r 's/vfat.*/vfat defaults 0 0/g' arch_root/etc/fstab
sed -i -r 's/,subvolid=[0-9]+//g' arch_root/etc/fstab
sed -i -r 's/space_cache/ssd,space_cache/g' arch_root/etc/fstab
sed -i -r 's/.*swapfile.*//g' arch_root/etc/fstab

# Setup swap
SWAP_FILE=arch_root/swap/swapfile
touch $SWAP_FILE
chattr +C $SWAP_FILE
fallocate --length "4GB" $SWAP_FILE
chmod 600 $SWAP_FILE
mkswap $SWAP_FILE
echo '/swap/swapfile          none            swap            defaults        0 0' >> arch_root/etc/fstab

# Add kernel module for usb booting
if [ -f arch_root/boot/boot.scr ]; then
    sed -i 's/^MODULES=.*/MODULES=(pcie_brcmstb)/' arch_root/etc/mkinitcpio.conf

    KERNEL_VER=$(basename arch_root/lib/modules/*-ARCH)

    mkinitcpio \
        --kernel "$KERNEL_VER" \
        --moduleroot ./arch_root \
        --hookdir ./arch_root/usr/lib/initcpio \
        --config ./arch_root/etc/mkinitcpio.conf \
        --generate ./arch_root/boot/initramfs-linux.img
fi

# https://www.kernel.org/doc/html/v5.0/admin-guide/kernel-parameters.html
# /etc/modprobe.d/blacklist_uas_152d.conf
#echo "152d:0583:u" | sudo tee /sys/module/usb_storage/parameters/quirks
CMDLINE_EXTRA="rootflags=subvol=\/@ audit=0 ipv6.disable=1 usb-storage.quirks=152d:0578:u,152d:0583:u cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1 swapaccount=1"

if [ -f arch_root/boot/cmdline.txt ]; then
    # armv7
    sed -i "s#/dev/mmcblk0p2#UUID=${PART_ROOT_UUID}#" arch_root/boot/cmdline.txt
    sed -i "s/ rw / rw ${CMDLINE_EXTRA} /" arch_root/boot/cmdline.txt
    sed -i "s#/dev/mmcblk0p1#UUID=${PART_BOOT_UUID}#g" arch_root/etc/fstab
    echo 'dtoverlay=w1-gpio' > arch_root/boot/config.txt
elif [ -f arch_root/boot/boot.scr ]; then
    # aarch64
    sed -i "s#/dev/mmcblk0p1#UUID=${PART_BOOT_UUID}#g" arch_root/etc/fstab
    sed -i 's/^part.*//g' arch_root/boot/boot.txt
    sed -i "s/root=PARTUUID=\${uuid}/root=UUID=${PART_ROOT_UUID}"'/' arch_root/boot/boot.txt
    sed -i "s/ rw / rw ${CMDLINE_EXTRA} /" arch_root/boot/boot.txt
    cd arch_root/boot && ./mkscr && cd ../..
else
    die "Unknown boot structure"
fi

sync

#umount -R root
#rmdir root
