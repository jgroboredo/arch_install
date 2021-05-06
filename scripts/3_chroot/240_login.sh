#!/bin/bash

# == Login ==

if [ "$ARCH_AUTOLOGIN" == 'yes' ]; then
    if [ "$(command -v sddm)" ]; then
        {
            echo "[Autologin]"
            echo "User=$ARCH_USER"
            echo "Session=plasma.desktop"
        } > /etc/sddm.conf.d/autologin.conf
    else
        mkdir -p /etc/systemd/system/getty@tty1.service.d
        cat > /etc/systemd/system/getty@tty1.service.d/override.conf <<EOT
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin $ARCH_USER --noclear %I \$TERM
EOT
    fi
else
    mkdir -p /etc/systemd/system/getty@tty1.service.d
    cat > /etc/systemd/system/getty@tty1.service.d/override.conf <<EOT
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty -n -o $ARCH_USER %I
EOT
fi
