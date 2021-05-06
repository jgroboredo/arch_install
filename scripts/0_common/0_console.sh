#!/bin/bash
# shellcheck disable=SC2059

function printline() {
    linechar=${1:--}
    cols=$(tput cols)
    for ((i=0; i<cols; i++));do printf "$linechar"; done; echo
}

function info() {
    printf "[${CYAN}INFO${NOCOLOR}] %s\n" "$@"
}

function warn() {
    printf "[${YELLOW}WARN${NOCOLOR}] %s\n" "$@"
}

function fail() {
    printf "[${RED}FAIL${NOCOLOR}] %s\n" "$@"
    exit 1
}

function die() {
    printf "[${RED}FAIL${NOCOLOR}] %s\n" "$@"
    exit 1
}

function pause() {
    echo ""
    printline "="
    printf "[${PURPLE}PAUSE${NOCOLOR}] $1, press ENTER to continue"
    if [ "$ARCH_UNATTENDED" != 'yes' ]; then
        read -n 1 -s -r
    fi
    echo
    printline "="
    echo
}
