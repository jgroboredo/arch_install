#!/bin/bash

# == ssh access ==

if [ ! -f "$ROOT_DIR/id_rsa.pub" ]; then
    warn "No id_rsa.pub provided, not enabling sshd"
else
    for usr in "$ARCH_ADMIN" "$ARCH_USER"; do
        info "Setting $usr authorized_keys"
        mkdir -p "/home/$usr/.ssh"
        chown "$usr:$usr" "/home/$usr/.ssh"
        chmod 700 "/home/$usr/.ssh"
        cat "$ROOT_DIR/id_rsa.pub" > "/home/$usr/.ssh/authorized_keys"
        chown "$usr:$usr" "/home/$usr/.ssh/authorized_keys"
    done

    info "Enabling sshd"

    systemctl --quiet enable sshd
fi
