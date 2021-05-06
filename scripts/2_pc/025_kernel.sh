#!/bin/bash

# == linux-ck kernel ==

if [[ "$ARCH_KERNEL" == linux-ck* ]]; then
    info "Will install ck kernel '$ARCH_KERNEL'"

    if ! grep -q repo-ck /etc/pacman.conf; then
        {
            echo "[repo-ck]"
            echo "Server = http://repo-ck.com/\$arch"
        } >> /etc/pacman.conf

        pacman-key -r 5EE46C4C
        pacman-key --lsign-key 5EE46C4C
    fi
fi
