#!/bin/bash

set -euo pipefail  # x for debug

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
export ROOT_DIR

INSIDE_CHROOT='no'
if systemd-detect-virt --chroot; then
    INSIDE_CHROOT='yes'
fi

# Source common scripts
for s in "$ROOT_DIR/aux_scripts"/*.sh; do
    source "$s"
done

##################################################################################
############################### CONFIG #################################
##################################################################################

#Default values for needed variables

ARCH_ADMIN_UID=1995
ARCH_CHROOT=.chroot
ARCH_CPU_BRAND=aarch64 #armv7h
ARCH_DISK=mmcblk0
ARCH_HOSTNAME=goncalo-pi
ARCH_LANG=en
ARCH_RAM_GB=4
ARCH_USERS=goncalo
ARCH_PRESET='no'
ARCH_UNATTENDED='no'
ARCH_BOOT_MODE='pi'
ARCH_PACKAGES='pi'

if [ "$ARCH_CPU_BRAND" = 'armv7h' ]; then
    ARCH_KERNEL='linux-rpi'
    elif [ "$ARCH_CPU_BRAND" = 'aarch64' ]; then
    # ARCH_KERNEL='linux-aarch64' this is outdated
    ARCH_KERNEL='linux-rpi'
else
    fail 'Unknown pi arch'
fi

ARCH_RAM_GB=${ARCH_RAM_GB:-$(grep MemTotal /proc/meminfo | awk '{printf "%.0f", $2 / 1024 / 1024}')}
ARCH_SWAP=${ARCH_SWAP:-$ARCH_RAM_GB}


if [ "$ARCH_PRESET" != 'yes' ]; then
    read -r -e -p "Disk: /dev/"       -i "$ARCH_DISK" ARCH_DISK
    read -r -e -p "Users: "           -i "$ARCH_USERS" ARCH_USERS
    if [[ "$ARCH_USERS" != "${ARCH_USERS%[[:space:]]*}" ]]; then
        # Only ask for admin if there are multiple users
        read -r -e -p "Admin: "       -i "$ARCH_ADMIN"      ARCH_ADMIN
    else
        ARCH_ADMIN="$ARCH_USERS"
    fi
    read -r -e -p "Language: "        -i "$ARCH_LANG"       ARCH_LANG
    read -r -e -p "Swap (GB): "       -i "$ARCH_SWAP"       ARCH_SWAP
    read -r -e -p "Kernel: "          -i "$ARCH_KERNEL"     ARCH_KERNEL
fi

printline "="

# -- users pws
function config_pw() {
    
    printline "-"
    
    declare -A ARCH_USER_PASSWORDS
    
    for usr in $ARCH_USERS; do
        printline "-"
        read_password "User '$usr'" "ARCH_USER_PASSWORDS[$usr]"
    done
    
    printline "-"
}

# -- check config
function check_config() {
    
    if [ ! -b "/dev/$ARCH_DISK" ]; then
        fail "Device /dev/$ARCH_DISK does not exist"
    fi
}

# -- check dependencies

function check_dependencies() {
    requirements=(aria2c mkimage bsdtar parted btrfs genfstab arch-chroot)
    for cmd in "${requirements[@]}"; do
        [ "$(command -v "$cmd")" ] || die "$cmd is not installed, needed for chrooting mode"
    done
}

# -- print config
function print_config() {
    printline "="
    
    printf "${CYAN}Host:${NOCOLOR} $ARCH_HOSTNAME\n"
    printf "${CYAN}Boot:${NOCOLOR} $ARCH_BOOT_MODE\n"
    printf "${CYAN}CPU:${NOCOLOR}  $ARCH_CPU_BRAND\n"
    printline "-"
    printf "${CYAN}Disk:${NOCOLOR} $ARCH_DISK\n"
    printf "${CYAN}Swap:${NOCOLOR} $ARCH_SWAP\n"
    printline "-"
    printf "${CYAN}Users:${NOCOLOR}      $ARCH_USERS\n"
    printf "${CYAN}Admin:${NOCOLOR}      $ARCH_ADMIN (uid=$ARCH_ADMIN_UID)\n"
    printf "${CYAN}Kernel:${NOCOLOR}     $ARCH_KERNEL\n"
    printf "${CYAN}Language:${NOCOLOR}   $ARCH_LANG\n"
    printf "${CYAN}Unattended:${NOCOLOR} $ARCH_UNATTENDED\n"
    printline "="
    
    pause 'Check configuration'
}

##################################################################################
############################### AUX FUNCTIONS #############################
##################################################################################

# == Sync clock ==

function sync_clock() {
    timedatectl set-ntp true
    sleep 2
    
    if ! timedatectl status | grep -q 'System clock synchronized: yes'; then
        fail "Failed to synchronize clock with NTP"
        elif ! timedatectl status | grep -q 'NTP service: active'; then
        fail "Failed to synchronize clock with NTP"
    else
        info 'Clock: Synchronized'
    fi
}

# ==========================================================================

# == Partition and mount disk ==

function disk_partitions() {
    # shellcheck disable=SC2153  # ignore misspellings
    
    [ ! -d "$ARCH_CHROOT" ] || die "There are leftovers in $ARCH_CHROOT from a previous run"
    [ -b "/dev/$ARCH_DISK" ] || die "Device /dev/$ARCH_DISK does not exist"
    
    # shellcheck disable=SC2143
    [ -z "$(mount | grep "/dev/$ARCH_DISK")" ] || die "$ARCH_DISK is mounted somewhere"
    
    fdisk -l "/dev/$ARCH_DISK"
    
    pause "Will partition /dev/$ARCH_DISK for $ARCH_BOOT_MODE"
    
    parted --script "/dev/$ARCH_DISK" \
    mklabel msdos \
    mkpart primary fat32 1M 200MiB \
    mkpart primary btrfs 200MiB 100%
    
    fdisk -l "/dev/$ARCH_DISK"
    
    pause "Partitioned /dev/$ARCH_DISK"
    
    # == Set the partition variables ==
    
    ARCH_DISK_P=$ARCH_DISK
    if [[ "$ARCH_DISK_P" == nvme* ]] || [[ "$ARCH_DISK_P" == mmcblk* ]]; then
        ARCH_DISK_P="${ARCH_DISK_P}p"
    fi
    
    export ARCH_DISK_BOOT_PART="/dev/${ARCH_DISK_P}1"
    export ARCH_DISK_ROOT_PART="/dev/${ARCH_DISK_P}2"
}

# ==========================================================================

# == Create btrfs subvolumes ==

function disk_btrfs_mount() {
    
    info "Formatting $ARCH_DISK_BOOT_PART as FAT32"
    mkfs.vfat -F32 -n "BOOT" "$ARCH_DISK_BOOT_PART"
    
    # shellcheck disable=SC2153  # not a misspelling
    info "Formatting $ARCH_DISK_ROOT_PART as btrfs"
    mkfs.btrfs -f -L "Arch Linux" "$ARCH_DISK_ROOT_PART"
    
    
    info "Creating btrfs subvolumes"
    
    mkdir -p "$ARCH_CHROOT"
    
    mount -t btrfs -o noatime "$ARCH_DISK_ROOT_PART" "$ARCH_CHROOT"
    
    btrfs subvolume create "$ARCH_CHROOT/@"
    btrfs subvolume create "$ARCH_CHROOT/@home"
    btrfs subvolume create "$ARCH_CHROOT/@storage"
    btrfs subvolume create "$ARCH_CHROOT/@swap"
    btrfs subvolume create "$ARCH_CHROOT/@var_log"
    btrfs subvolume create "$ARCH_CHROOT/@var_cache"
    
    umount -R "$ARCH_CHROOT"
    
    # == Mount everything ==
    
    info "Mounting partitions"
    
    BTRFS_MOUNT_FLAGS=noatime,x-mount.mkdir,compress=zstd
    
    mount -t btrfs -o $BTRFS_MOUNT_FLAGS,subvol=/@          "$ARCH_DISK_ROOT_PART" "$ARCH_CHROOT"
    mount -t btrfs -o $BTRFS_MOUNT_FLAGS,subvol=/@home      "$ARCH_DISK_ROOT_PART" "$ARCH_CHROOT/home"
    mount -t btrfs -o $BTRFS_MOUNT_FLAGS                    "$ARCH_DISK_ROOT_PART" "$ARCH_CHROOT/mnt/root"
    mount -t btrfs -o $BTRFS_MOUNT_FLAGS,subvol=/@storage   "$ARCH_DISK_ROOT_PART" "$ARCH_CHROOT/mnt/storage"
    mount -t btrfs -o $BTRFS_MOUNT_FLAGS,subvol=/@swap      "$ARCH_DISK_ROOT_PART" "$ARCH_CHROOT/swap"
    mount -t btrfs -o $BTRFS_MOUNT_FLAGS,subvol=/@var_log   "$ARCH_DISK_ROOT_PART" "$ARCH_CHROOT/var/log"
    mount -t btrfs -o $BTRFS_MOUNT_FLAGS,subvol=/@var_cache "$ARCH_DISK_ROOT_PART" "$ARCH_CHROOT/var/cache"
    
    btrfs property set "$ARCH_CHROOT/mnt/storage" compression zstd
    chown -c "$ARCH_ADMIN_UID:$ARCH_ADMIN_UID" "$ARCH_CHROOT/mnt/storage"
    chmod -c 700 "$ARCH_CHROOT/mnt/storage"
    
    mkdir -p "$ARCH_CHROOT/boot"
    mount "$ARCH_DISK_BOOT_PART" "$ARCH_CHROOT/boot"
    
    # Sync and reload partition table
    sync
    sleep 2
    partprobe "/dev/$ARCH_DISK"
}

# ==========================================================================

# == Setup Swap ==

function setup_swap() {
    SWAP_FILE="$ARCH_CHROOT/swap/swapfile"
    
    if [ -z "$ARCH_SWAP" ] || [ "$ARCH_SWAP" == 'no' ]; then
        info "No swap"
        return 0
    fi
    
    info "Setting up ${ARCH_SWAP}GB swap"
    
    if [ ! -f "$SWAP_FILE" ]; then
        touch "$SWAP_FILE"
        chattr +C "$SWAP_FILE"
        fallocate --length "${ARCH_SWAP}GB" "$SWAP_FILE"
        chmod 600 "$SWAP_FILE"
        mkswap "$SWAP_FILE"
    fi
    
    swapon "$SWAP_FILE"
}

# ==========================================================================

# == Pacman & pacstrap ==

function pacstrapping() {
    PACSTRAP_CONF=/tmp/pacstrap.conf
    
    if [ -f "$PACSTRAP_CONF" ]; then
        rm -f "$PACSTRAP_CONF"
    fi
    
    cp "$ROOT_DIR/files/etc/pacstrap_arm.conf" "$PACSTRAP_CONF"
    sed -i "s/ARM_REPLACE_ME/$ARCH_CPU_BRAND/g" "$PACSTRAP_CONF"
    
    if [ -d /tmp/pacstrap_arm ]; then
        rm -rf /tmp/pacstrap_arm
    fi
    mkdir -p /tmp/pacstrap_arm/var/lib/pacman/
    
    KEYRING_PKG="$(wget --quiet -O - "http://mirror.archlinuxarm.org/$ARCH_CPU_BRAND/core/" | sed -n "s/.*\(archlinuxarm-keyring-[0-9]\+-[0-9]\+-any.pkg.tar.xz\).*/\1/p" | head -n 1)"
    KEYRING_URL="http://mirror.archlinuxarm.org/$ARCH_CPU_BRAND/core/$KEYRING_PKG"
    if [ ! -f "/tmp/$KEYRING_PKG" ]; then
        wget --quiet --show-progress --directory-prefix="/tmp" "$KEYRING_URL"
        wget --quiet --show-progress --directory-prefix="/tmp" "${KEYRING_URL}.sig"
    fi
    
    # This is outdated
    # check_sha1 "bee268fb4409aa89c1a182049bf33ccdf427712a" "/tmp/$KEYRING_PKG" || \
    # check_sha1 "da5b0633a7d8cdbe9aeeae3b38563a89f723d4d0" "/tmp/$KEYRING_PKG" || \
    # fail "Failed to verify $KEYRING_PKG checksum"
    
    # https://github.com/archlinuxarm/archlinuxarm-keyring/blob/master/archlinuxarm.gpg
    # Verify keys
    # TODO This is not working
    # gpg --locate-keys builder@archlinuxarm.org
    
    # if gpg --keyserver-options auto-key-retrieve --verify "/tmp/${KEYRING_PKG}.sig" "/tmp/${KEYRING_PKG}" 2>&1 >/dev/null | grep -q "Good"
    # then
    #     echo "Good signatures"
    # else
    #     echo "Bad signatures. Exiting..."
    #     exit 1
    # fi
    
    tar -C / -xvf "/tmp/$KEYRING_PKG" usr
    
    pacman-key --config "$PACSTRAP_CONF" --init
    pacman-key --config "$PACSTRAP_CONF" --populate archlinuxarm
    
    sed -i 's/^# *\(Color\)/\1/' "$PACSTRAP_CONF"
    sed -i 's/^# *\(ParallelDownloads.*\)/\1/' "$PACSTRAP_CONF"
    
    # == Pacstrap ==
    
    pause "Before pacstrap"
    
    pacstrap -G -M -C "$PACSTRAP_CONF" "$ARCH_CHROOT" \
    base base-devel \
    zsh sudo \
    mkinitcpio btrfs-progs archlinuxarm-keyring\
    "$ARCH_KERNEL" "$ARCH_KERNEL-headers" linux-firmware crda \
    iptables-nft
    
    # Fix the mirrorlist inside the chroot
    cp "$ROOT_DIR/files/etc/pacman.d/mirrorlist-arm" "$ARCH_CHROOT/etc/pacman.d/mirrorlist"
    
    # Copy the pacman db
    mkdir -p "$ARCH_CHROOT/var/lib/pacman"
    rsync -r /tmp/pacstrap_arm/var/lib/pacman/ "$ARCH_CHROOT/var/lib/pacman"
}

# ==========================================================================

# == fstab ==

function fstab() {
    {
        echo "# Static information about the filesystems."
        echo "# See fstab(5) for details."
        echo ""
        echo "# <file system> <dir> <type> <options> <dump> <pass>"
        echo ""
    } > "$ARCH_CHROOT/etc/fstab"
    
    genfstab -U "$ARCH_CHROOT" >> "$ARCH_CHROOT/etc/fstab"
    sed -i -r 's/,subvolid=[0-9]+//g' "$ARCH_CHROOT/etc/fstab"
    
    if [ "$(cat /sys/block/$ARCH_DISK/queue/rotational)" -eq 0 ] || [ "$ARCH_BOOT_MODE" == 'pi' ]; then
        sed -i -r 's/space_cache/ssd,space_cache/g' "$ARCH_CHROOT/etc/fstab"
    fi
    
    printline '-'
    
    cat "$ARCH_CHROOT/etc/fstab"
    
    pause "Check the fstab"
    
}

# ==========================================================================

# == chroot ==

function go_chroot() {
    
    rm -rf "$ARCH_CHROOT/arch_install"
    
    rsync --copy-links --recursive --archive \
    --exclude ".git" \
    --exclude ".chroot" \
    --exclude ".archlive" \
    --exclude "last_tag.txt" \
    --exclude "*.tar.gz" \
    "$ROOT_DIR/" "$ARCH_CHROOT/arch_install"
    
    chown -R root:root "$ARCH_CHROOT/arch_install"
    chmod 700 "$ARCH_CHROOT/arch_install"
    
    set +euo pipefail
    
    arch-chroot "$ARCH_CHROOT" /arch_install/arch_install_pi.sh chrooting
}

# ==========================================================================

# == system ==

function system_config() {
    # == Temporary dns ==
    
    echo 'nameserver 1.1.1.2' > /etc/resolv.conf
    
    # == Timezone, locale and language ==
    
    ln -sf /usr/share/zoneinfo/Europe/Lisbon /etc/localtime
    hwclock --systohc
    
    if [ "$ARCH_LANG" == 'en' ]; then
        ARCH_LOCALE='en_US'
        elif [ "$ARCH_LANG" == 'pt' ]; then
        ARCH_LOCALE='pt_PT'
    else
        fail "Unknown lang '$ARCH_LANG'"
    fi
    
    sed -i "s/^#\(pt_PT.UTF-8\)/\1/" /etc/locale.gen
    sed -i "s/^#\($ARCH_LOCALE.UTF-8\)/\1/" /etc/locale.gen
    
    locale-gen
    
    echo "LANG=$ARCH_LOCALE.UTF-8" > /etc/locale.conf
    echo 'KEYMAP=pt-latin9' > /etc/vconsole.conf
    echo "$ARCH_HOSTNAME" > /etc/hostname
    echo "Welcome to $ARCH_HOSTNAME!" > /etc/motd
    
    cat > /etc/hosts <<EOF
    127.0.0.1       localhost $ARCH_HOSTNAME
    ::1             localhost $ARCH_HOSTNAME
EOF
    
    # == Pacman ==
    
    pacman_enable_repo 'multilib'
    
    sed -i 's/^# *\(Color\)/\1/' /etc/pacman.conf
    sed -i 's/^# *\(ParallelDownloads.*\)/\1/' /etc/pacman.conf
    # sed -E -i "s/^PKGEXT=.*/PKGEXT='.pkg.tar'/" /etc/makepkg.conf
    # shellcheck disable=SC2016  # expressions in single quotes
    sed -E -i 's/^#MAKEFLAGS=.*/MAKEFLAGS="-j$(nproc)"/' /etc/makepkg.conf
    
    if [ ! -d /etc/pacman.d/gnupg/ ]; then
        pacman-key --init
        pacman-key --populate archlinuxarm
    fi
    
}

# ==========================================================================

# == Packages ==

function packages() {
    if [ ! "$(command -v yq)" ]; then
        pacman -Sy --needed --noconfirm yq
    fi
    
    packages=()
    pkgs_cmd=""
    
    for p in "${packages[@]}"; do
        pkgs_cmd+=" $p"
    done
    
    # shellcheck disable=SC2086
    # shellcheck disable=SC2116
    for pkg_cat in \
    boot.$ARCH_BOOT_MODE \
    cpu.$ARCH_CPU_BRAND \
    $(echo $ARCH_PACKAGES); \
    do
        if [[ $pkg_cat == aur* ]] && [[ $pkg_cat != aur.helper.* ]]; then
            continue
        fi
        
        load_packages "$pkg_cat"
        # shellcheck disable=SC2154
        pkgs_cmd+=" "$ret_packages
    done
    
    # shellcheck disable=SC2086
    info "Will install: $pkgs_cmd"
    
    pause "Before installing packages"
    
    # shellcheck disable=SC2086
    pacman -Syu --needed --noconfirm $pkgs_cmd
}

# ==========================================================================

# == preconfigured dotfiles ==

function dot_files() {
    printline '='
    
    rm -rf /etc/skel/.bash*
    rm -f  /etc/skel/.keep
    
    # deploy dotfiles
    RSYNC_CMD="rsync --inplace --recursive --copy-links --perms --times"
    RSYNC_CMD="$RSYNC_CMD --exclude .keep"
    $RSYNC_CMD "$ROOT_DIR/files/" "/"
    
    
    # fonts, from https://gist.github.com/cryzed/e002e7057435f02cc7894b9e748c5671
    # if [ -d /etc/fonts ]; then
    #     ln -sf /usr/share/fontconfig/conf.avail/11-lcdfilter-default.conf /etc/fonts/conf.d
    #     ln -sf /usr/share/fontconfig/conf.avail/10-sub-pixel-rgb.conf /etc/fonts/conf.d
    # fi
    
    # Fix sudoers permission
    chmod -c 750 "/etc/sudoers.d"
    chmod -c 440 "/etc/sudoers.d/secure"
    chmod -c 750 "/etc/polkit-1/rules.d"
    
    # The mirrorlist was already setup by pacstrap
    rm -f /etc/pacman.d/mirrorlist-*
    
    rm -f /etc/pacman.d/hooks/*-efi-*.hook
    
    echo 'NO_AT_BRIDGE=1' >> /etc/environment
}

# ==========================================================================

# == users ==

function config_users() {
    # shellcheck disable=SC2002
    # shellcheck disable=SC2059
    
    # == root ==
    
    printline '='
    info "Setting root password"
    printline '='
    
    # Disable pipefail to generate the password
    set +o pipefail
    
    ARCH_ROOT_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
    printf "$ARCH_ROOT_PASSWORD\n$ARCH_ROOT_PASSWORD\n" | passwd root
    
    info "Disabling root user"
    passwd -l root
    chmod 700 /root
    
    # Re-enable pipefail
    set -o pipefail
    
    for usr in $ARCH_USERS; do
        printline '='
        info "Creating user $usr"
        printline '='
        
        if [ "$usr" == "$ARCH_ADMIN" ]; then
            info "Creating user for admin"
            useradd --create-home -u "$ARCH_ADMIN_UID" "$ARCH_ADMIN"
            usermod -a -G wheel "$ARCH_ADMIN"
        else
            useradd --create-home "$usr"
        fi
        
        chmod 700 "/home/$usr"
        chsh -s "/bin/zsh" "$usr"
        
        temp_pw=""
        read_password "User '$usr'" "temp_pw"
        printf "${temp_pw}\n${temp_pw}\n" | passwd "$usr"
        
        info "Password set for user $usr"
        
    done
    
    # == delete alarm ==
    
    if id "alarm" &>/dev/null; then
        info "Deleting alarm"
        userdel -r "alarm"
        
        usermod -aG video "$ARCH_ADMIN"
    fi
    
    pause 'Users created'
}

# ==========================================================================

# == Boot ==

function bootloader(){
    # == Boot ==
    
    #usb line fixes no boot from poor ssh cage
    KERNEL_OPTS='usb-storage.quirks=174c:5136:u,152d:0578:u,152d:0583:u audit=0' # ipv6.disable=1
    
    if [ "$(command -v apparmor_status)" ]; then
        KERNEL_OPTS="apparmor=1 lsm=lockdown,yama,apparmor,bpf $KERNEL_OPTS"
    fi
    
    info "Setting up pi bootloader"
    
    PART_ROOT_UUID=$(blkid -o value -s UUID "$(mount | grep "on / " | cut -d ' ' -f1)")
    
    # Add kernel module for usb booting
    if [ -f /boot/boot.scr ]; then
        sed -i 's/^MODULES=.*/MODULES=(pcie_brcmstb)/' /etc/mkinitcpio.conf
        
        KERNEL_VER=$(basename /lib/modules/*-ARCH)
        
        mkinitcpio \
        --kernel "$KERNEL_VER" \
        --moduleroot / \
        --hookdir /usr/lib/initcpio \
        --config /etc/mkinitcpio.conf \
        --generate /boot/initramfs-linux.img
    fi
    
    KERNEL_OPTS="$KERNEL_OPTS rootflags=subvol=\/@ cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1 swapaccount=1"
    
    if [ -f /boot/cmdline.txt ]; then
        # armv7h
        sed -i "s#/dev/mmcblk0p2#UUID=${PART_ROOT_UUID}#" /boot/cmdline.txt
        sed -i "s/ rw / rw ${KERNEL_OPTS} /" /boot/cmdline.txt
        sed -i "s/dtoverlay=/dtoverlay=w1-gpio,/" /boot/config.txt
        # TODO sed "initramfs .+.img"
        elif [ -f /boot/boot.scr ]; then
        # aarch64
        sed -i 's/^part.*//g' /boot/boot.txt
        sed -i "s/root=PARTUUID=\${uuid}/root=UUID=${PART_ROOT_UUID}"'/' /boot/boot.txt
        sed -i "s/ rw / rw ${KERNEL_OPTS} /" /boot/boot.txt
        sed -i -E 's/ smsc95xx.macaddr="[^"]+"//' /boot/boot.txt
        cd /boot && ./mkscr && cd ../..
    else
        die "Unknown boot structure"
    fi
    
    # Overclock
    # Check that arm_boost=1
cat >> /boot/config.txt <<EOF
over_voltage=6
arm_freq=1800
EOF
    
}

# ==========================================================================

function network() {
    # Network Manager
    if [ "$(command -v nmcli)" ]; then
        info "Enabling NetworkManager"
        systemctl --quiet enable NetworkManager
        systemctl --quiet mask NetworkManager-wait-online.service
        elif [ "$(command -v dhcpcd)" ]; then
        info "Enabling dhcpcd"
        systemctl --quiet enable dhcpcd
    fi
    
    # DNS
    info "Enabling systemd-resolved"
    systemctl --quiet enable systemd-resolved
    
    # firewall
    info "Enabling iptables"
    systemctl --quiet enable iptables
}

# ==========================================================================

# == Login ==

function login() {
    mkdir -p /etc/systemd/system/getty@tty1.service.d
    cat > /etc/systemd/system/getty@tty1.service.d/override.conf <<EOF
    [Service]
    ExecStart=
    ExecStart=-/usr/bin/agetty -n -o $ARCH_ADMIN %I
EOF
    
}

# ==========================================================================

# == Fix Permissions ==

function fix_permissions() {
    
    SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
    
    # Dirs
    while IFS="" read -r p || [ -n "$p" ]
    do
        permission="$(echo $p | awk '{print $1}')"
        dir="$(echo $p | awk '{print $2}')"
        if [[ -d "${dir}" ]]; then
            chmod "${permission}" "${dir}"
        else
            echo "Dir $dir not found"
        fi
    done < "${SCRIPT_DIR}/permissions_etc_dirs.txt"
    
    # Files
    while IFS="" read -r p || [ -n "$p" ]
    do
        permission="$(echo $p | awk '{print $1}')"
        file="$(echo $p | awk '{print $2}')"
        if [[ -f "${file}" ]]; then
            chmod "${permission}" "${file}"
        else
            echo "File $file not found"
        fi
    done < "${SCRIPT_DIR}/permissions_etc_files.txt"
}

# ==========================================================================

# == Services ==

function enable_services() {
    # NTP time sync
    systemctl --quiet enable systemd-timesyncd.service
    
    # Docker
    if [ "$(command -v docker)" ]; then
        info "Enabling docker"
        
        systemctl --quiet enable docker
        usermod -a -G docker "$ARCH_ADMIN"
        
    fi
    
    if [ "$(cat /sys/block/$ARCH_DISK/queue/rotational)" -eq 0 ]; then
        info "Enabling fstrim.timer ($ARCH_DISK is ssd)"
        
        systemctl --quiet enable fstrim.timer
    fi
    
    # AppArmor
    if [ "$(command -v apparmor_status)" ]; then
        info "Enabling apparmor"
        
        systemctl --quiet enable apparmor
    fi
    
    # CUPS
    if [ "$(command -v cupsd)" ]; then
        info "Enabling cups"
        
        systemctl --quiet enable cups
    fi
    
    # wireshark
    if [ "$(command -v wireshark)" ]; then
        info "Setting up wireshark for admin user"
        
        usermod -a -G wireshark "$ARCH_ADMIN"
    fi
    
    # fail2ban
    if [ "$(command -v fail2ban-server)" ]; then
        info "Enabling fail2ban"
        
        systemctl --quiet enable fail2ban
    fi
    
    # ddclient
    if [ "$(command -v ddclient)" ]; then
        info "Enabling ddclient"
        
        systemctl --quiet enable ddclient
    fi
    
    # earlyoom
    if [ "$(command -v earlyoom)" ]; then
        info "Enabling earlyoom"
        
        systemctl --quiet enable earlyoom
    fi
    
    # systemd-swap
    if [ "$(command -v systemd-swap)" ]; then
        info "Enabling systemd-swap"
        
        systemctl --quiet enable systemd-swap
    fi
    
    # realtime
    if [ -f usr/lib/sysusers.d/realtime-privileges.conf ]; then
        for usr in $ARCH_USERS; do
            info "Enabling realtime privileges for $usr"
            usermod -a -G realtime "$usr"
        done
    fi
    
    # pcscd
    if [ "$(command -v pcscd)" ]; then
        info "Enabling pcscd"
        
        systemctl --quiet enable pcscd
    fi
    
    # snapper
    if [ "$(command -v snapper)" ]; then
        info "Setting up snapper"
        
        snapper --no-dbus -c root create-config /
        snapper --no-dbus -c home create-config /home
        systemctl --quiet enable snapper-cleanup.timer
    fi
    
    # == ssh access ==
    
    info "Enabling sshd"
    
    systemctl --quiet enable sshd
}

# ==========================================================================

function chroot_cleanup() {
    printline '='
    pause 'All done in chroot'
    touch /arch_install/success
    
    if ask "Open bash in chroot before leaving?" N; then
        bash
    fi
    
    # Override resolv.conf for dnscrypt-proxy
    # We can't do this in the dotfiles or we'll lose network connection
    if [ "$(command -v dnscrypt-proxy)" ]; then
        echo 'nameserver 127.0.0.1' > /etc/resolv.conf
    fi
}

function final_cleanup() {
    if [ -n "$ARCH_SWAP" ]; then
        info 'Turning off swap'
        swapoff "$ARCH_CHROOT/swap/swapfile" 2>/dev/null || true
    fi
    
    set -euo pipefail
    
    if [ ! -f "$ARCH_CHROOT/arch_install/success" ]; then
        fail 'Something failed inside the chroot'
    fi
    
    sync
    
    echo
    printline '-'
    
    info "Umounting $ARCH_CHROOT recursively"
    umount -R "$ARCH_CHROOT"
    printline '-'
    
    rmdir "$ARCH_CHROOT"
    
}

##################################################################################
############################### MAIN ##################################
##################################################################################

function first_setup() {
    check_config
    check_dependencies
    print_config
    sync_clock
    disk_partitions
    disk_btrfs_mount
    setup_swap
    pacstrapping
    fstab
    go_chroot
    final_cleanup
}

function inside_chroot() {
    system_config
    packages
    dot_files
    config_users
    bootloader
    network
    login
    fix_permissions
    enable_services
    chroot_cleanup
}

if [ "${1-default}" == "chrooting" ]
then
    echo "Inside chroot"
    pause "Check state"
    inside_chroot
else
    echo "Outside chroot"
    pause "Check state"
    first_setup
fi

