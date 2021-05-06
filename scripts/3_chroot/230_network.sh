#!/bin/bash

# Network Manager
if [ "$(command -v nmcli)" ]; then
    info "Enabling NetworkManager"
    systemctl --quiet enable NetworkManager
    systemctl --quiet mask NetworkManager-wait-online.service
fi

# DNS
if [ "$(command -v dnscrypt-proxy)" ]; then
    info "Replacing systemd-resolved with dnscrypt-proxy"
    systemctl --quiet disable systemd-resolved
    systemctl --quiet enable dnscrypt-proxy
    sed -i -E \
        "s/^# server_names.*/server_names = ['cloudflare-security', 'quad9-doh-ip4-filter-pri']/" \
        /etc/dnscrypt-proxy/dnscrypt-proxy.toml
else
    warn "dnscrypt-proxy not installed"
    #rm -f /etc/NetworkManager/NetworkManager.conf
fi

# firewall
if [ "$(command -v firewall-cmd)" ]; then
    info "Enabling firewalld"
    systemctl --quiet enable firewalld
else
    info "Enabling iptables"
    systemctl --quiet enable iptables
fi
