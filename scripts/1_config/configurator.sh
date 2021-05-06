#!/bin/bash
# shellcheck disable=SC2059
# shellcheck disable=SC2002
# shellcheck disable=SC2016

if [ -f "$ROOT_DIR/config.sh" ]; then
    rm "$ROOT_DIR/config.sh"
fi

if nc -z -w 1 10.0.1.1 80 || nc -z -w 1 10.0.2.1 80; then
    ARCH_HOSTNAME='rebelo-'
else
    ARCH_HOSTNAME='paulo-'
fi

read -r -e -p "Hostname: " -i "$ARCH_HOSTNAME" ARCH_HOSTNAME

# Presets
if [ "$ARCH_HOSTNAME" == 'rebelo-ge60' ]; then
    ARCH_PRESET='yes'
    ARCH_LUKS='yes'
    ARCH_PACKAGES='core extra xorg.core xorg.extra'
elif [ "$ARCH_HOSTNAME" == 'rebelo-zen' ]; then
    ARCH_PRESET='yes'
    ARCH_DISK='nvme0n1'
    ARCH_LUKS='yes'
    ARCH_TESTING='yes'
    ARCH_PACKAGES='core extra xorg.core xorg.extra'
elif [ "$ARCH_HOSTNAME" == 'rebelo-qemu' ]; then
    ARCH_TESTING='yes'
elif [ "$ARCH_HOSTNAME" == 'rebelo-phenom' ]; then
    ARCH_USER='rebelo'
    ARCH_LANG='pt'
    ARCH_AUTOLOGIN='yes'
elif [ "$ARCH_HOSTNAME" == 'rebelo-x550lb' ]; then
    ARCH_USER='idalina'
    ARCH_LANG='pt'
    ARCH_AUTOLOGIN='yes'
elif [ "$ARCH_HOSTNAME" == 'rebelo-pi' ]; then
    ARCH_CHROOTING='yes'
    ARCH_PRESET='yes'
    ARCH_DISK='sda'
    ARCH_LUKS='no'
    ARCH_TESTING='no'
    ARCH_PACKAGES='pi'
    ARCH_CPU_BRAND='armv7' # 'aarch64'
    if [ "$ARCH_CPU_BRAND" = 'armv7' ]; then
        ARCH_KERNEL='linux-raspberrypi4'
    elif [ "$ARCH_CPU_BRAND" = 'aarch64' ]; then
        ARCH_KERNEL='linux-aarch64'
    else
        fail 'Unknown pi arch'
    fi
    ARCH_RAM_GB='4'
    ARCH_AUR_HELPER='none'
    ARCH_TAG_LIST='001,010,099,110,120,130,140,220,230,250,290,999'
elif [[ "$ARCH_HOSTNAME" == paulo-* ]]; then
    ARCH_USER='paulo'
    ARCH_ADMIN='paulo'
fi

ARCH_PRESET=${ARCH_PRESET:-no}
ARCH_DISK=${ARCH_DISK:-sda}
ARCH_USER=${ARCH_USER:-jose}
ARCH_ADMIN=${ARCH_ADMIN:-jose}
if [ "$ARCH_ADMIN" == 'jose' ]; then
    ARCH_ADMIN_UID=${ARCH_ADMIN_UID:-1995}
else
    ARCH_ADMIN_UID=${ARCH_ADMIN_UID:-1000}
fi
ARCH_LANG=${ARCH_LANG:-en}
ARCH_LUKS=${ARCH_LUKS:-no}
ARCH_RAM_GB=${ARCH_RAM_GB:-$(grep MemTotal /proc/meminfo | awk '{printf "%.0f", $2 / 1024 / 1024}')}
ARCH_SWAP=${ARCH_SWAP:-$ARCH_RAM_GB}
ARCH_KERNEL=${ARCH_KERNEL:-linux-zen}
ARCH_AUTOLOGIN=${ARCH_AUTOLOGIN:-no}
ARCH_TESTING=${ARCH_TESTING:-no}
ARCH_PACKAGES=${ARCH_PACKAGES:-core extra xorg.core xorg.extra login_gui}
ARCH_AUR_HELPER=${ARCH_AUR_HELPER:-paru}
ARCH_UNATTENDED=${ARCH_UNATTENDED:-no}
ARCH_CHROOTING=${ARCH_CHROOTING:-no}
ARCH_TAG_LIST=${ARCH_TAG_LIST:-}

if [ "$ARCH_PRESET" == 'yes' ] && ! ask "Use preset for $ARCH_HOSTNAME"; then
    ARCH_PRESET='no'
fi

if [ "$ARCH_PRESET" != 'yes' ]; then
    read -r -e -p "Disk: /dev/" -i "$ARCH_DISK" ARCH_DISK
    read -r -e -p "User: " -i "$ARCH_USER" ARCH_USER
    read -r -e -p "Admin: " -i "$ARCH_ADMIN" ARCH_ADMIN
    read -r -e -p "Language: " -i "$ARCH_LANG" ARCH_LANG
    read -r -e -p "Luks encryption: " -i "$ARCH_LUKS" ARCH_LUKS
    read -r -e -p "Swap (GB): " -i "$ARCH_SWAP" ARCH_SWAP
    read -r -e -p "Testing repos: " -i "$ARCH_TESTING" ARCH_TESTING
    read -r -e -p "Kernel: " -i "$ARCH_KERNEL" ARCH_KERNEL
    read -r -e -p "Packages: " -i "$ARCH_PACKAGES" ARCH_PACKAGES
    read -r -e -p "AUR Helper: " -i "$ARCH_AUR_HELPER" ARCH_AUR_HELPER
    read -r -e -p "Auto login on boot: " -i "$ARCH_AUTOLOGIN" ARCH_AUTOLOGIN
fi

# -- passwords
printline "="
printline "="

if [ "$ARCH_LUKS" == 'yes' ]; then
    read -r -e -s -p "LUKS password: " ARCH_LUKS_PASSWORD </dev/tty
    echo
    read -r -e -s -p "LUKS password: " ARCH_LUKS_PASSWORD_2 </dev/tty
    echo

    if [ "$ARCH_LUKS_PASSWORD" != "$ARCH_LUKS_PASSWORD_2" ]; then
        fail "Luks passwords are different"
    fi
fi

printline "-"

read -r -e -s -p "User '$ARCH_ADMIN' password: " ARCH_ADMIN_PASSWORD </dev/tty
echo
read -r -e -s -p "User '$ARCH_ADMIN' password: " ARCH_ADMIN_PASSWORD_2 </dev/tty
echo

if [ "$ARCH_ADMIN_PASSWORD" != "$ARCH_ADMIN_PASSWORD_2" ]; then
    fail "User '$ARCH_ADMIN' passwords are different"
fi

if [ "$ARCH_USER" != "$ARCH_ADMIN" ]; then
    printline "-"

    read -r -e -s -p "User '$ARCH_USER' password: " ARCH_USER_PASSWORD </dev/tty
    echo
    read -r -e -s -p "User '$ARCH_USER' password: " ARCH_USER_PASSWORD_2 </dev/tty
    echo

    if [ "$ARCH_USER_PASSWORD" != "$ARCH_USER_PASSWORD_2" ]; then
        fail "User '$ARCH_USER' passwords are different"
    fi
fi

printline "-"

# -- Unattended

read -r -e -p "Unattended install: " -i "$ARCH_UNATTENDED" ARCH_UNATTENDED

# -- boot mode

if [ -z "$ARCH_CHROOTING" ]; then
    if [ -d '/sys/firmware/efi' ]; then
        ARCH_BOOT_MODE='efi'
    else
        ARCH_BOOT_MODE='bios'
    fi
else
    ARCH_BOOT_MODE='chroot_unknown'
fi

# -- vm

if [ -z "$ARCH_CHROOTING" ]; then
    ARCH_VM="$(systemd-detect-virt || return 0)"

    if [ "$ARCH_VM" != 'none' ]; then
        ARCH_PACKAGES="$ARCH_PACKAGES vm.$ARCH_VM"
    fi
else
    ARCH_VM='chroot_unknown'
fi

# -- cpu brand

if [ -z "$ARCH_CHROOTING" ]; then
    CPU_VENDOR=$(grep vendor /proc/cpuinfo | uniq)
    if echo "$CPU_VENDOR" | grep -q -i intel; then
        ARCH_CPU_BRAND='intel'
    elif echo "$CPU_VENDOR" | grep -q -i amd; then
        ARCH_CPU_BRAND='amd'
    else
        fail "Unrecognized CPU vendor '$CPU_VENDOR'"
    fi
else
    ARCH_CPU_BRAND=${ARCH_CPU_BRAND:-chroot_unknown}
fi

# -- gpu brand

ARCH_GPU_TYPE='none'

if [ -z "$ARCH_CHROOTING" ]; then
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
    elif [ "$ARCH_VM" != 'none' ]; then
        ARCH_GPU_TYPE="gpu_vm_$ARCH_VM"
    else
        fail 'Unrecognized GPU vendor'
    fi
else
    ARCH_GPU_TYPE=${ARCH_GPU_TYPE:-chroot_unknown}
fi

# -- check config

if [ ! -b "/dev/$ARCH_DISK" ]; then
    fail "Device /dev/$ARCH_DISK does not exist"
fi

# shellcheck disable=SC2001
# shellcheck disable=SC2086
for pkg_cat in $(echo $ARCH_PACKAGES); do
    if [[ $(cat "$ROOT_DIR/scripts/1_config/packages.yml" | yq -r ".$pkg_cat[]") == "null" ]]; then
        fail "Package category '$pkg_cat' not found"
    fi
done

# -- print config

printline "="

printf "${CYAN}Host:${NOCOLOR} $ARCH_HOSTNAME\n"
printf "${CYAN}Boot:${NOCOLOR} $ARCH_BOOT_MODE\n"
printf "${CYAN}CPU:${NOCOLOR} $ARCH_CPU_BRAND\n"
printf "${CYAN}Graphics:${NOCOLOR} $ARCH_GPU_TYPE\n"
printf "${CYAN}Virtual Machine:${NOCOLOR} $ARCH_VM\n"
printline "-"
printf "${CYAN}Disk:${NOCOLOR} $ARCH_DISK\n"
printf "${CYAN}Luks:${NOCOLOR} $ARCH_LUKS\n"
printf "${CYAN}Swap:${NOCOLOR} $ARCH_SWAP\n"
printline "-"
printf "${CYAN}User:${NOCOLOR} $ARCH_USER\n"
printf "${CYAN}Admin:${NOCOLOR} $ARCH_ADMIN (uid=$ARCH_ADMIN_UID)\n"
printf "${CYAN}Packages:${NOCOLOR} $ARCH_PACKAGES\n"
printf "${CYAN}AUR Helper:${NOCOLOR} $ARCH_AUR_HELPER\n"
printf "${CYAN}Testing repositories:${NOCOLOR} $ARCH_TESTING\n"
printf "${CYAN}Kernel:${NOCOLOR} $ARCH_KERNEL\n"
printf "${CYAN}Language:${NOCOLOR} $ARCH_LANG\n"
printf "${CYAN}Automatic login:${NOCOLOR} $ARCH_AUTOLOGIN\n"
printf "${CYAN}Unattended install:${NOCOLOR} $ARCH_UNATTENDED\n"
printline "-"
printf "${CYAN}Tags:${NOCOLOR} $ARCH_TAG_LIST\n"
printline "="

pause 'Check configuration'

# -- save to disk

{
    echo "#!/bin/bash"
    echo "ARCH_HOSTNAME=$ARCH_HOSTNAME"
    echo "ARCH_DISK=$ARCH_DISK"
    echo "ARCH_USER=$ARCH_USER"
    echo "ARCH_VM=$ARCH_VM"
    echo "ARCH_TESTING=$ARCH_TESTING"
    echo "ARCH_PACKAGES=$ARCH_PACKAGES"
    echo "ARCH_AUR_HELPER=$ARCH_AUR_HELPER"
    echo "ARCH_ADMIN=$ARCH_ADMIN"
    echo "ARCH_ADMIN_UID=$ARCH_ADMIN_UID"
    echo "ARCH_LANG=$ARCH_LANG"
    echo "ARCH_LUKS=$ARCH_LUKS"
    echo "ARCH_SWAP=$ARCH_SWAP"
    echo "ARCH_BOOT_MODE=$ARCH_BOOT_MODE"
    echo "ARCH_CPU_BRAND=$ARCH_CPU_BRAND"
    echo "ARCH_GPU_TYPE=$ARCH_GPU_TYPE"
    echo "ARCH_KERNEL=$ARCH_KERNEL"
    echo "ARCH_AUTOLOGIN=$ARCH_AUTOLOGIN"
    echo "ARCH_UNATTENDED=$ARCH_UNATTENDED"
    echo "ARCH_TAG_LIST=$ARCH_TAG_LIST"
} >> "$ROOT_DIR/config.sh"

{
    echo "#!/bin/bash"
    echo "ARCH_LUKS_PASSWORD=${ARCH_LUKS_PASSWORD:-}"
    echo "ARCH_ADMIN_PASSWORD=${ARCH_ADMIN_PASSWORD:-}"
    echo "ARCH_USER_PASSWORD=${ARCH_USER_PASSWORD:-}"
} >> "$ROOT_DIR/passwords.sh"
