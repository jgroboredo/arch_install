#!/bin/bash

# Virt Manager
if [ "$(command -v virt-manager)" ]; then
    info "Enabling virt-manager"

    systemctl --quiet enable libvirtd

    usermod -a -G kvm "$ARCH_ADMIN"
    usermod -a -G libvirt "$ARCH_ADMIN"
    #sed -i -E "s/^#user = .*/user = \"$ARCH_ADMIN\"/g" /etc/libvirt/qemu.conf
    #sed -i -E "s/^#group = .*/group = \"$ARCH_ADMIN\"/g" /etc/libvirt/qemu.conf
fi

# arduino
if [ "$(command -v arduino)" ]; then
    usermod -a -G uucp "$ARCH_ADMIN"
fi

# Docker
if [ "$(command -v docker)" ]; then
    info "Enabling docker"

    systemctl --quiet enable docker
    usermod -a -G docker "$ARCH_ADMIN"

    #if [ "$(command -v firewall-cmd)" ]; then
    #    firewall-cmd --zone=trusted --change-interface=docker0
    #fi
fi

if [ "$(cat /sys/block/$ARCH_DISK/queue/rotational)" -eq 0 ]; then
    info "Enabling fstrim.timer ($ARCH_DISK is ssd)"

    systemctl --quiet enable fstrim.timer
fi

# AppArmor
if [ "$(command -v apparmor_status)" ]; then
    info "Enabling apparmor"

    systemctl --quiet enable apparmor
fi

# Bluetooth
if [ "$(command -v bluetoothctl)" ]; then
    info "Enabling bluetooth"

    systemctl --quiet enable bluetooth
fi

# CUPS
if [ "$(command -v cupsd)" ]; then
    info "Enabling cups"

    systemctl --quiet enable cups
    echo a4 > /etc/papersize
fi

# SDDM
if [ "$(command -v sddm)" ]; then
    info "Enabling sddm"

    systemctl --quiet enable sddm
fi

# wireshark
if [ "$(command -v wireshark)" ]; then
    info "Setting up wireshark for admin user"

    usermod -a -G wireshark "$ARCH_ADMIN"
fi

# fail2ban
if [ "$(command -v fail2ban-client)" ]; then
    info "Enabling fail2ban"

    mkdir -p /var/log/fail2ban/

    systemctl --quiet enable fail2ban
fi

# ddclient
if [ "$(command -v ddclient)" ]; then
    info "Enabling ddclient"

    systemctl --quiet enable ddclient
fi

# earlyoom
if [ "$(command -v earlyoom)" ]; then
    info "Enabling earlyoom"

    systemctl --quiet enable earlyoom
fi

# systemd-swap
if [ "$(command -v systemd-swap)" ]; then
    info "Enabling systemd-swap"

    systemctl --quiet enable systemd-swap
fi

# realtime
if [ -f usr/lib/sysusers.d/realtime-privileges.conf ]; then
    for usr in "$ARCH_ADMIN" "$ARCH_USER"; do
        info "Enabling realtime privileges for $usr"
        usermod -a -G realtime "$usr"
    fi
fi

# pcscd
if [ "$(command -v pcscd)" ]; then
    info "Enabling pcscd"

    systemctl --quiet enable pcscd
fi

#systemctl enable avahi-daemon.service
# TODO mdns_minimal [NOTFOUND=return] to /etc/nsswitch.conf before resolve
