#!/bin/bash

if [ ! -d /etc/pacman.d/gnupg/ ]; then
    pacman-key --init

    if [ "$ARCH_CPU_BRAND" == 'armv7' ] || [ "$ARCH_CPU_BRAND" == 'aarch64' ]; then
        pacman-key --populate archlinuxarm
    fi
fi

# == Packages ==

if [ ! $(command -v yq) ]; then
    pacman -Syu --needed --noconfirm yq
fi

packages=()
pkgs_cmd=""

for p in "${packages[@]}"; do
    pkgs_cmd+=" $p"
done

# shellcheck disable=SC2001
# shellcheck disable=SC2086
for pkg_cat in \
    boot.$ARCH_BOOT_MODE \
    gpu.$ARCH_GPU_TYPE \
    cpu.$ARCH_CPU_BRAND \
    aur_helper.$ARCH_AUR_HELPER \
    hosts.\"$ARCH_HOSTNAME\" \
    $(echo $ARCH_PACKAGES); \
do
    info "Loading packages for '$pkg_cat'"
    if [[ "$(cat $ROOT_DIR/scripts/1_config/packages.yml | yq -r ".$pkg_cat")" == "null" ]]; then
        warn "Packages for '$pkg_cat' not found"
        continue
    fi

    pkgs_cmd+=" "$(\
        cat $ROOT_DIR/scripts/1_config/packages.yml | \
            yq -r ".$pkg_cat[]" | \
            sed -E 's/(\[|\]|"|,)//g' | \
            sed ':a;N;$!ba;s/\n/ /g' \
    )
done

# shellcheck disable=SC2086
info "Will install: $pkgs_cmd"

pause "Before installing packages"

# shellcheck disable=SC2086
pacman -Syu --needed --noconfirm $pkgs_cmd
