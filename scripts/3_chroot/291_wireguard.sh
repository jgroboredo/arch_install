#!/bin/bash

if [ -f "$ROOT_DIR/wg0.conf" ]; then
    info "Enabling wireguard@wg0"

    mkdir -p "/etc/wireguard"
    chmod 700 "/etc/wireguard"
    cat "$ROOT_DIR/wg0.conf" > "/etc/wireguard/wg0.conf"
    systemctl --quiet enable wg-quick@wg0
fi
