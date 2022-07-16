#!/bin/bash

#Check if run with root
if [ "$EUID" -ne 0 ]
then echo "Please run as root"
    exit
fi



ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Sourcing utils (has load_packages)
source "./aux_scripts/utils.sh"
source "./aux_scripts/ask.sh"
source "./aux_scripts/colors.sh"
source "./aux_scripts/console.sh"


# checking if yq dependency is installed
if [ ! "$(command -v yq)" ]; then
    pacman -Sy --needed --noconfirm yq
fi

CORE_DESKTOP_PKGS='core pipewire.core bluetooth printers xorg.core i3'
EXTRA_DESKTOP_PKGS='pipewire.extra extra xorg.extra'
ARCH_PACKAGES="$CORE_DESKTOP_PKGS $EXTRA_DESKTOP_PKGS"

pkgs_cmd=""

for p in "${packages[@]}"; do
    pkgs_cmd+=" $p"
done

# shellcheck disable=SC2086
# shellcheck disable=SC2116
for pkg_cat in \
$(echo $ARCH_PACKAGES); \
do
    load_packages "$pkg_cat"
    # shellcheck disable=SC2154
    pkgs_cmd+=" "$ret_packages
done

# shellcheck disable=SC2086
info "Will verify: $pkgs_cmd"

pause "Before verifying packages"

# shellcheck disable=SC2086
packages=($pkgs_cmd)
errors=0

for pak in "${packages[@]}"
do
    info "Will verify: $pak"
    search="$(pacman -Si $pak | grep "Name" | awk '{print $3}')"
    if [ ! "$search" = "$pak" ]
    then
        echo $pak does not exist
    fi
done
