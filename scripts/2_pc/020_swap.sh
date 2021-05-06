#!/bin/bash

# == Setup Swap ==

SWAP_FILE=/mnt/swap/swapfile

if [ -z "$ARCH_SWAP" ] || [ "$ARCH_SWAP" == 'no' ]; then
    info "No swap"
else
    info "Setting up ${ARCH_SWAP}GB swap"

    if [ ! -f "$SWAP_FILE" ]; then
        touch $SWAP_FILE
        chattr +C $SWAP_FILE
        fallocate --length "${ARCH_SWAP}GB" $SWAP_FILE
        chmod 600 $SWAP_FILE
        mkswap $SWAP_FILE
    fi

    swapon $SWAP_FILE
fi
