#!/bin/bash

# shellcheck disable=SC2059  # not using variables in printf

if [ -z "$NOCOLOR" ]; then
    # shellcheck disable=SC1091
    source "$ROOT_DIR/aux_scripts/colors.sh"
fi

function printline() {
    linechar=${1:--}
    cols=$(tput cols)
    for ((i=0; i<cols; i++));do printf "$linechar"; done; echo
}

function current_sh() {
    for src in "${BASH_SOURCE[@]}"; do
        filename=$(basename "${src}")
        if [ "$filename" != "console.sh" ] && [ "$filename" != "utils.sh" ]; then
            printf %-22.22s "${filename%.*}"
            return
        fi
    done
}

function log() {
    printf "$(date +'%F %T') "                  # timestamp
    printf "[${1}${2}${NOCOLOR}] "              # level
    if [[ "$INSIDE_CHROOT" == 'yes' ]]; then
        printf "${RED}$(current_sh)${NOCOLOR}: " # location, chroot
    else
        printf "${PURPLE}$(current_sh)${NOCOLOR}: " # location, non-chroot
    fi
    printf "%s\n" "${@:3}"                      # message
}

function info() {
    log "${CYAN}" "INFO" "$@"
}

function warn() {
    log "${YELLOW}" "WARN" "$@"
}

function fail() {
    log "${RED}" "FAIL" "$@"
    exit 1
}

function die() {
    log "${RED}" "FAIL" "$@"
    exit 1
}

function pause() {
    if [ "$ARCH_UNATTENDED" == 'yes' ]; then
        return
    fi
    echo ""
    printline "="
    printf "[${PURPLE}PAUSE${NOCOLOR}] $1, press ENTER to continue"
    read -n 1 -s -r
    echo
    printline "="
    echo
}
