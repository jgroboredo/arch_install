#!/bin/bash

# == Pacman ==

function pacman_enable_repo () {
    sed -i "/\[$1\]/,/Include/"'s/^#//' "${2:-/etc/pacman.conf}"
}

function pacman_delete_repo () {
    sed -i "/\[$1\]/,+1 d" "${2:-/etc/pacman.conf}"
    sed -i "/\[$1\]/,/Include/"'s/^#//' "${2:-/etc/pacman.conf}"
}

function check_sha1 () {
    echo "$1 *$2" | sha1sum -c -
}

function load_packages() {
    info "Loading packages for '$pkg_cat'"

    pkg_cat="$1"
    ret_packages=""

    # shellcheck disable=SC2002  # useless cat
    if [[ "$(cat "$ROOT_DIR/config/packages.yml" | yq -r ".$pkg_cat")" == "null" ]]; then
        warn "Packages for '$pkg_cat' not found"
        return
    fi

    # shellcheck disable=SC2002  # useless cat
    # shellcheck disable=SC2034  # unused ret_packages
    # shellcheck disable=SC1087  # not using braces to expand array
    ret_packages=$(\
        cat "$ROOT_DIR/config/packages.yml" | \
            yq -r ".$pkg_cat[]" | \
            sed -E 's/(\[|\]|"|,)//g' | \
            sed ':a;N;$!ba;s/\n/ /g' \
    )
}

function read_password() {
    read -r -e -s -p "$1 password: " THE_PASSWORD   </dev/tty
    echo
    read -r -e -s -p "$1 password: " THE_PASSWORD_2 </dev/tty
    echo

    if [ "$THE_PASSWORD" != "$THE_PASSWORD_2" ]; then
        fail "$1 passwords are different"
    fi

    eval "$2=$THE_PASSWORD"
}
