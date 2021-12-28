#!/bin/bash

set -euo pipefail  # x for debug

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
export ROOT_DIR

# Source common scripts
for s in "$ROOT_DIR/aux_scripts"/*.sh; do
    source "$s"
done

##################################################################################
    ############################### CONFIG #################################
##################################################################################

#Default values for needed variables

CORE_DESKTOP_PKGS='core pipewire.core bluetooth printers xorg.core i3'
EXTRA_DESKTOP_PKGS='pipewire.extra extra xorg.extra'

ARCH_ADMIN_UID=1995
ARCH_DISK=sda
ARCH_HOSTNAME=goncalo
ARCH_LANG=en
ARCH_KEYBOARD='pt-latin9'
ARCH_RAM_GB=4
ARCH_USERS=goncalo
ARCH_PRESET='no'
ARCH_INSTALL_DOTFILES='no'
ARCH_INSTALL_AUR='no'
ARCH_UNATTENDED='no'
ARCH_PACKAGES="$CORE_DESKTOP_PKGS $EXTRA_DESKTOP_PKGS"

ARCH_RAM_GB=${ARCH_RAM_GB:-$(grep MemTotal /proc/meminfo | awk '{printf "%.0f", $2 / 1024 / 1024}')}
ARCH_SWAP=${ARCH_SWAP:-$ARCH_RAM_GB}
ARCH_AUR_HELPER=${ARCH_AUR_HELPER:-yay}
ARCH_KERNEL=${ARCH_KERNEL:-linux}
ARCH_CHROOT=${ARCH_CHROOT:-.chroot}

# -- boot mode

if [ -d '/sys/firmware/efi' ]; then
    ARCH_BOOT_MODE='efi'
else
    ARCH_BOOT_MODE='bios'
fi

# -- cpu brand

CPU_VENDOR=$(grep vendor /proc/cpuinfo | uniq)
if echo "$CPU_VENDOR" | grep -q -i intel; then
    ARCH_CPU_BRAND='intel'
elif echo "$CPU_VENDOR" | grep -q -i amd; then
    ARCH_CPU_BRAND='amd'
else
    fail "Unrecognized CPU vendor '$CPU_VENDOR'"
fi

# -- gpu brand

if lspci | grep -q -i "VGA.*\WIntel"; then
    ARCH_GPU_TYPE='intel'
    if lspci | grep -q -i "3D.*\WNVIDIA"; then
        ARCH_GPU_TYPE='optimus'
    fi
elif lspci | grep -q -i "3D.*\WNVIDIA"; then
    ARCH_GPU_TYPE='nvidia'
elif lspci | grep -q -i "VGA.*\WAMD"; then
    ARCH_GPU_TYPE='amd'
elif lspci | grep -q -i "VGA.*\WATI"; then
    ARCH_GPU_TYPE='ati'
else
    lspci | grep 'VGA\|3D'
    fail 'Unrecognized GPU vendor'
fi

if [ "$ARCH_PRESET" != 'yes' ]; then
    read -r -e -p "Disk: /dev/"       -i "$ARCH_DISK" ARCH_DISK
    read -r -e -p "Users: "           -i "$ARCH_USERS" ARCH_USERS
    if [[ "$ARCH_USERS" != "${ARCH_USERS%[[:space:]]*}" ]]; then
        # Only ask for admin if there are multiple users
        read -r -e -p "Admin: "       -i "$ARCH_ADMIN"      ARCH_ADMIN
    else
        ARCH_ADMIN="$ARCH_USERS"
    fi
    read -r -e -p "Language: "     -i "$ARCH_LANG"          ARCH_LANG
    read -r -e -p "Swap (GB): "    -i "$ARCH_SWAP"          ARCH_SWAP
    read -r -e -p "Kernel: "       -i "$ARCH_KERNEL"        ARCH_KERNEL
    read -r -e -p "Keyboard: "     -i "$ARCH_KEYBOARD"      ARCH_KEYBOARD
    read -r -e -p "Dot Files: "    -i "$ARCH_INSTALL_DOTFILES"      ARCH_INSTALL_DOTFILES
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

# -- print config
function print_config() {
    printline "="

    printf "${CYAN}Host:${NOCOLOR} $ARCH_HOSTNAME\n"
    printf "${CYAN}Boot:${NOCOLOR} $ARCH_BOOT_MODE\n"
    printf "${CYAN}CPU:${NOCOLOR}  $ARCH_CPU_BRAND\n"
    printf "${CYAN}GPU:${NOCOLOR}  $ARCH_GPU_TYPE\n"
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

    case "$ARCH_BOOT_MODE" in
        efi)
            parted --script "/dev/$ARCH_DISK" \
                mklabel gpt \
                mkpart primary fat32 1MiB 550MiB \
                set 1 esp on \
                mkpart primary btrfs 550MiB 100%
        ;;

        bios)
            parted --script "/dev/$ARCH_DISK" \
                mklabel msdos \
                mkpart primary btrfs 1MiB 100% \
                set 1 boot on
        ;;

    
        *)
            die "Unknown boot mode $ARCH_BOOT_MODE"
        ;;
    esac

    fdisk -l "/dev/$ARCH_DISK"

    pause "Partitioned /dev/$ARCH_DISK"

    # == Set the partition variables ==

    ARCH_DISK_P=$ARCH_DISK
    if [[ "$ARCH_DISK_P" == nvme* ]] || [[ "$ARCH_DISK_P" == mmcblk* ]]; then
        ARCH_DISK_P="${ARCH_DISK_P}p"
    fi

    export ARCH_DISK_EFI_PART=""
    export ARCH_DISK_BOOT_PART=""

    if [ "$ARCH_BOOT_MODE" == 'efi' ]; then
        export ARCH_DISK_EFI_PART="/dev/${ARCH_DISK_P}1"
        export ARCH_DISK_ROOT_PART="/dev/${ARCH_DISK_P}2"
    elif [ "$ARCH_BOOT_MODE" == 'bios' ]; then
        export ARCH_DISK_ROOT_PART="/dev/${ARCH_DISK_P}1"
    else
        die "Unknown boot mode $ARCH_BOOT_MODE"
    fi
}

# ==========================================================================

function disk_btrfs_mount() {
    
    if [ -n "$ARCH_DISK_EFI_PART" ]; then
        info "Formatting $ARCH_DISK_EFI_PART as FAT32"
        mkfs.vfat -F32 -n "BOOT" "$ARCH_DISK_EFI_PART"
    fi

    if [ -n "$ARCH_DISK_BOOT_PART" ]; then
        info "Formatting $ARCH_DISK_BOOT_PART as FAT32"
        mkfs.vfat -F32 -n "BOOT" "$ARCH_DISK_BOOT_PART"
    fi

    # shellcheck disable=SC2153  # not a misspelling
    info "Formatting $ARCH_DISK_ROOT_PART as btrfs"
    mkfs.btrfs -f -L "Arch Linux" "$ARCH_DISK_ROOT_PART"

    # == Create btrfs subvolumes ==

    info "Creating btrfs subvolumes"

    mkdir -p "$ARCH_CHROOT"

    mount -t btrfs -o noatime "$ARCH_DISK_ROOT_PART" "$ARCH_CHROOT"

    btrfs subvolume create "$ARCH_CHROOT/@"
    btrfs subvolume create "$ARCH_CHROOT/@home"
    btrfs subvolume create "$ARCH_CHROOT/@storage"
    btrfs subvolume create "$ARCH_CHROOT/@swap"
    btrfs subvolume create "$ARCH_CHROOT/@var_log"
    btrfs subvolume create "$ARCH_CHROOT/@var_cache"

    if [ "$ARCH_BOOT_MODE" == 'efi' ]; then
        btrfs subvolume create "$ARCH_CHROOT/@recovery"
    fi

    umount -R "$ARCH_CHROOT"

    # == Mount everything ==

    info "Mounting partitions"

    mount -t btrfs -o noatime,x-mount.mkdir,compress=zstd,subvol=/@          "$ARCH_DISK_ROOT_PART" "$ARCH_CHROOT"
    mount -t btrfs -o noatime,x-mount.mkdir,compress=zstd,subvol=/@home      "$ARCH_DISK_ROOT_PART" "$ARCH_CHROOT/home"
    mount -t btrfs -o noatime,x-mount.mkdir,compress=zstd                    "$ARCH_DISK_ROOT_PART" "$ARCH_CHROOT/mnt/root"
    mount -t btrfs -o noatime,x-mount.mkdir,compress=zstd,subvol=/@storage   "$ARCH_DISK_ROOT_PART" "$ARCH_CHROOT/mnt/storage"
    mount -t btrfs -o noatime,x-mount.mkdir,compress=zstd,subvol=/@swap      "$ARCH_DISK_ROOT_PART" "$ARCH_CHROOT/swap"
    mount -t btrfs -o noatime,x-mount.mkdir,compress=zstd,subvol=/@var_log   "$ARCH_DISK_ROOT_PART" "$ARCH_CHROOT/var/log"
    mount -t btrfs -o noatime,x-mount.mkdir,compress=zstd,subvol=/@var_cache "$ARCH_DISK_ROOT_PART" "$ARCH_CHROOT/var/cache"

    btrfs property set "$ARCH_CHROOT/mnt/storage" compression zstd
    chown -c "$ARCH_ADMIN_UID:$ARCH_ADMIN_UID" "$ARCH_CHROOT/mnt/storage"
    chmod -c 700 "$ARCH_CHROOT/mnt/storage"

    if [ "$ARCH_BOOT_MODE" == 'efi' ]; then
        mount -t btrfs -o noatime,x-mount.mkdir,compress=zstd,subvol=/@recovery  "$ARCH_DISK_ROOT_PART" "$ARCH_CHROOT/recovery"
    fi

    if [ -n "$ARCH_DISK_EFI_PART" ]; then
        mkdir -p "$ARCH_CHROOT/efi"
        mount "$ARCH_DISK_EFI_PART" "$ARCH_CHROOT/efi"
    fi

    if [ -n "$ARCH_DISK_BOOT_PART" ]; then
        mkdir -p "$ARCH_CHROOT/boot"
        mount "$ARCH_DISK_BOOT_PART" "$ARCH_CHROOT/boot"
    fi

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

function pacstrap() {
    PACSTRAP_CONF=/tmp/pacstrap.conf

    if [ -f "$PACSTRAP_CONF" ]; then
        rm -f "$PACSTRAP_CONF"
    fi

    cp /etc/pacman.conf "$PACSTRAP_CONF"

    pacman_enable_repo 'multilib' "$PACSTRAP_CONF"

    # Replace all mirrorlists with ours
    sed -i "s#/etc/pacman.d/mirrorlist#$ROOT_DIR/files/etc/pacman.d/mirrorlist-x86#g" "$PACSTRAP_CONF"

    sed -i 's/^# *\(Color\)/\1/' "$PACSTRAP_CONF"
    sed -i 's/^# *\(ParallelDownloads.*\)/\1/' "$PACSTRAP_CONF"

    # == Pacstrap ==

    pause "Before pacstrap"

    pacstrap -G -M -C "$PACSTRAP_CONF" "$ARCH_CHROOT" \
        base base-devel \
        zsh sudo \
        mkinitcpio btrfs-progs \
        "$ARCH_KERNEL" "$ARCH_KERNEL-headers" linux-firmware crda \
        iptables-nft

    # Fix the mirrorlist inside the chroot
    cp "$ROOT_DIR/files/etc/pacman.d/mirrorlist-x86" "$ARCH_CHROOT/etc/pacman.d/mirrorlist"

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

    rsync -L -r -a \
        --exclude .git \
        --exclude .chroot \
        --exclude .archlive \
        --exclude last_tag.txt \
        --exclude "*.tar.gz" \
        "$ROOT_DIR/" "$ARCH_CHROOT/arch_install"

    chown -R root:root "$ARCH_CHROOT/arch_install"
    chmod 700 "$ARCH_CHROOT/arch_install"

    set +euo pipefail

    arch-chroot "$ARCH_CHROOT" /arch_install/arch_install.sh chrooting 
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
    echo "KEYMAP=$ARCH_KEYBOARD" > /etc/vconsole.conf
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
    sed -E -i "s/^PKGEXT=.*/PKGEXT='.pkg.tar'/" /etc/makepkg.conf
    # shellcheck disable=SC2016  # expressions in single quotes
    sed -E -i 's/^#MAKEFLAGS=.*/MAKEFLAGS="-j$(nproc)"/' /etc/makepkg.conf

    if [ ! -d /etc/pacman.d/gnupg/ ]; then
        pacman-key --init
        pacman-key --populate archlinux
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
        gpu.$ARCH_GPU_TYPE \
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
    if [ -d /etc/fonts ]; then
        ln -sf /usr/share/fontconfig/conf.avail/11-lcdfilter-default.conf /etc/fonts/conf.d
        ln -sf /usr/share/fontconfig/conf.avail/10-sub-pixel-rgb.conf /etc/fonts/conf.d
    fi

    # Fix sudoers permission
    chmod -c 750 "/etc/sudoers.d"
    chmod -c 440 "/etc/sudoers.d/secure"
    chmod -c 750 "/etc/polkit-1/rules.d"

    rm -f /etc/modules-load.d/w1.conf

    # The mirrorlist was already setup by pacstrap
    rm -f /etc/pacman.d/mirrorlist-*

    if [ "$ARCH_BOOT_MODE" != 'efi' ]; then
        rm -f /etc/pacman.d/hooks/*-efi-*.hook
    fi

    echo 'NO_AT_BRIDGE=1' >> /etc/environment
}

# ==========================================================================

# == kernel ==

function kernel_preset() {
    if [ "$(command -v mkinitcpio)" ] && [ "$ARCH_BOOT_MODE" != 'pi' ]; then
        if [ ! -f "/etc/mkinitcpio.d/$ARCH_KERNEL.preset" ]; then
            fail "Kernel $ARCH_KERNEL is not installed"
        fi

        sed -i "s/REPLACE_ME_PRESET/$ARCH_BOOT_MODE/g" /usr/share/mkinitcpio/hook.preset
        rm -f "/boot/initramfs-*fallback.img"

        rm -f "/etc/mkinitcpio.d/$ARCH_KERNEL.preset"
        cp /usr/share/mkinitcpio/hook.preset "/etc/mkinitcpio.d/$ARCH_KERNEL.preset"
        sed -i "s|%PKGBASE%|${ARCH_KERNEL}|g" "/etc/mkinitcpio.d/$ARCH_KERNEL.preset"
    fi
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
            useradd --create-home -u "$ARCH_ADMIN_UID" "$ARCH_ADMIN"
            usermod -a -G wheel "$ARCH_ADMIN"
        else
            useradd --create-home "$usr"
        fi

        chmod 700 "/home/$usr"
        chsh -s "/bin/zsh" "$usr"

        if [ -n "${ARCH_USER_PASSWORDS[$usr]}" ]; then
            printf "${ARCH_USER_PASSWORDS[$usr]}\n${ARCH_USER_PASSWORDS[$usr]}\n" | passwd "$usr"
        else
            passwd -d "$usr"
        fi
    done

    # == delete alarm ==

    if id "alarm" &>/dev/null; then
        info "Deleting alarm"
        userdel -r "alarm"

        usermod -aG video "$ARCH_ADMIN"
    fi
}

# ==========================================================================

# == Boot ==

function bootloader(){
    # shellcheck disable=SC2153
    ARCH_DISK_P=$ARCH_DISK
    if [[ "$ARCH_DISK_P" == nvme* ]]; then
        ARCH_DISK_P="${ARCH_DISK_P}p"
    fi

    # == Boot ==

    KERNEL_OPTS='usb-storage.quirks=174c:5136:u,152d:0578:u,152d:0583:u audit=0 ipv6.disable=1'

    KERNEL_OPTS="$KERNEL_OPTS snd_hda_intel.power_save=0"

    if [ "$ARCH_BOOT_MODE" == 'bios' ]; then
        sed -i "s/ quiet/$KERNEL_OPTS/" /etc/default/grub
        grub-install --target=i386-pc "/dev/$ARCH_DISK_P"
        grub-mkconfig -o /boot/grub/grub.cfg
    elif [ "$ARCH_BOOT_MODE" == 'efi' ]; then
        ROOT_OPTS="root=UUID=$(blkid -o value -s UUID /dev/${ARCH_DISK_P}2)"
        echo "${ROOT_OPTS} rootflags=subvol=/@ rw ${KERNEL_OPTS}" > /etc/kernel/cmdline

        mkdir -p /efi/EFI/systemd
        cp /usr/lib/systemd/boot/efi/systemd-bootx64.efi /efi/EFI/systemd/systemd-bootx64.efi

        # Boot entry
        efibootmgr --create \
            --disk "/dev/$ARCH_DISK" \
            --part "1" \
            --label "systemd-boot" \
            --loader "EFI\\systemd\\systemd-bootx64.efi" \
            --verbose
    fi
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
    if [ "$(command -v dnscrypt-proxy)" ]; then
        info "Replacing systemd-resolved with dnscrypt-proxy"
        systemctl --quiet disable systemd-resolved
        systemctl --quiet enable dnscrypt-proxy
        sed -i -E \
            "s/^# server_names.*/server_names = ['cloudflare-security', 'quad9-doh-ip4-filter-pri']/" \
            /etc/dnscrypt-proxy/dnscrypt-proxy.toml
    fi

    # firewall
    if [ "$(command -v firewall-cmd)" ]; then
        info "Enabling firewalld"
        systemctl --quiet enable firewalld
    else
        info "Enabling iptables"
        systemctl --quiet enable iptables
    fi
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

    # NetworkManager
    if [ "$(command -v NetworkManager)" ]; then
        info "Enabling NetworkManager"

        systemctl --quiet enable NetworkManager
    fi

    # tlp
    if [ "$(command -v tlp)" ]; then
        info "Enabling tlp"

        systemctl --quiet enable tlp.service
    fi

    # cpupower
    if [ "$(command -v cpupower)" ]; then
        info "Enabling cpupower"

        systemctl --quiet enable cpupower.service 
    fi

    # ntpd
    if [ "$(command -v ntpd)" ]; then
        info "Enabling ntpd"

        systemctl --quiet enable ntpd.service 
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

function install_dotfiles() {
    DOTFILES_CLONE_DIR=/home/$ARCH_ADMIN/Documents
    su -P "$ARCH_ADMIN" -c "mkdir -p $DOTFILES_CLONE_DIR"
    ZSHAUTO_CLONE_DIR=/home/$ARCH_ADMIN/.config

    #Creating .config folder for user
    su -P "$ARCH_ADMIN" -c "mkdir -p $ZSHAUTO_CLONE_DIR"

    #Creating vim pluggins directory
    su -P "$ARCH_ADMIN" -c "mkdir -p /home/$ARCH_ADMIN/.vim/plugged"
    
    #Creating cache directory for zsh
    su -P "$ARCH_ADMIN" -c "mkdir -p /home/$ARCH_ADMIN/.cache/zsh"
    su -P "$ARCH_ADMIN" -c "cd /home/$ARCH_ADMIN/.cache/zsh; touch dirs"

    #Creating lyx config folder
    su -P "$ARCH_ADMIN" -c "mkdir -p /home/$ARCH_ADMIN/.lyx"
        
    #Cloning needed repositories
    su -P "$ARCH_ADMIN" -c "cd $ZSHAUTO_CLONE_DIR; git clone https://github.com/zsh-users/zsh-autosuggestions.git"
    su -P "$ARCH_ADMIN" -c "cd $DOTFILES_CLONE_DIR; git clone https://github.com/jgroboredo/lap_dotfiles.git"

    #Installing dotfiles
    su -P "$ARCH_ADMIN" -c "cd $DOTFILES_CLONE_DIR/lap_dotfiles; sudo chmod +x install_bin.sh; sudo ./install_bin.sh"

    su -P "$ARCH_ADMIN" -c "cd $DOTFILES_CLONE_DIR/lap_dotfiles; sudo chmod +x install_dotfiles.sh; ./install_dotfiles.sh"

    #su -P "$ARCH_ADMIN" -c "cd $DOTFILES_CLONE_DIR/lap_dotfiles/grub_theme; sudo chmod +x install.sh; sudo ./install.sh"
    
    su -P "$ARCH_ADMIN" -c "cd $DOTFILES_CLONE_DIR/lap_dotfiles/xorg; sudo chmod +x install_xorg_confs.sh; sudo ./install_xorg_confs.sh"

    su -P "$ARCH_ADMIN" -c "cd $DOTFILES_CLONE_DIR/lap_dotfiles/lyx; sudo chmod +x install_lyx_conf.sh; ./install_lyx_conf.sh"
    
    #Applying wal theme
    #su -P "$ARCH_ADMIN" -c "wal --theme base16-nord"

    #Installing vim pluggins
    su -P "$ARCH_ADMIN" -c "vim +'PlugInstall --sync' +qa"
}

install_yay() {
    local packages=''

    if [ "$ARCH_AUR_HELPER" == 'none' ]; then
        echo '-'
        echo "Skipping AUR helper"
        echo '-'
    else
        echo '-'
        echo "Installing AUR helper '$ARCH_AUR_HELPER'"
        echo '-'

        AUR_HELPER_CLONE_DIR=/home/$ARCH_ADMIN/.cache/arch-install/aur_helper
        su -P "$ARCH_ADMIN" -c "mkdir -p $AUR_HELPER_CLONE_DIR"
        su -P "$ARCH_ADMIN" -c "cd $AUR_HELPER_CLONE_DIR; git clone https://aur.archlinux.org/$ARCH_AUR_HELPER.git"
        su -P "$ARCH_ADMIN" -c "cd $AUR_HELPER_CLONE_DIR/$ARCH_AUR_HELPER; makepkg -s"
        pacman --noconfirm -U "$AUR_HELPER_CLONE_DIR/$ARCH_AUR_HELPER/$ARCH_AUR_HELPER"*.pkg.tar*

        #packages+=' acpi clipit ttf-font-awesome hamsket-bin polkit-gnome pa-applet-git'

        #themes
        #packages+=' pop-gtk-theme-git pop-icon-theme-git'
        packages+=' arc-x-icons-theme'

        #mime-type handler
        #packages+=' mimeo xdg-utils-mimeo'
        packages+=' mimi-git'

        #misc
        #packages+=' vim-plug-git vim-youcompleteme-git zoom hunspell-pt_pt textext qtgrace dmenu-extended'
        #packages+=' fzwal-git'

        # == install packages from AUR ==
        su -P "$ARCH_ADMIN" -c "$ARCH_AUR_HELPER -S $packages"
    fi

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
    print_config
    sync_clock
    disk_partitions
    disk_btrfs_mount
    setup_swap
    pacstrap
    fstab
    go_chroot
    final_cleanup
}

function inside_chroot() {
    config_pw
    system_config
    packages
    dot_files
    kernel_preset
    config_users
    bootloader
    network
    login
    if [ "$ARCH_INSTALL_DOTFILES" == 'yes' ]; then
        install_dotfiles
    fi
    if [ "$ARCH_INSTALL_AUR" == 'yes' ]; then
        install_yay
    fi
    enable_services
    chroot_cleanup
}

set -ex

if [ "$1" == "chrooting" ]
then
    inside_chroot
else
    first_setup
fi

