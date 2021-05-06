#!/bin/bash
# shellcheck disable=SC2002
# shellcheck disable=SC2059

# == root ==

printline '='
info "Setting root password"
printline '='

# Disable pipefail to generate the password
set +o pipefail

ARCH_ROOT_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

printf "$ARCH_ROOT_PASSWORD\n$ARCH_ROOT_PASSWORD\n" | passwd root

info "Disabling root user"
passwd -l root

chmod 700 /root

# Re-enable pipefail
set -o pipefail

# == admin user ==

printline '='
info "Creating $ARCH_ADMIN ($ARCH_ADMIN_UID) and adding to wheel"
printline '='
useradd --create-home -u "$ARCH_ADMIN_UID" "$ARCH_ADMIN"
chmod 700 "/home/$ARCH_ADMIN"
usermod -a -G wheel "$ARCH_ADMIN"
chsh -s "/bin/zsh" "$ARCH_ADMIN"
printf "$ARCH_ADMIN_PASSWORD\n$ARCH_ADMIN_PASSWORD\n" | passwd "$ARCH_ADMIN"
#passwd "$ARCH_ADMIN"

# == normal user ==

if [ "$ARCH_USER" != "$ARCH_ADMIN" ]; then
    printline '='
    info "Creating user $ARCH_USER"
    printline '='
    useradd --create-home "$ARCH_USER"
    chmod 700 "/home/$ARCH_USER"
    printf "$ARCH_USER_PASSWORD\n$ARCH_USER_PASSWORD\n" | passwd "$ARCH_USER"
    #passwd "$ARCH_USER"
    chsh -s "/bin/zsh" "$ARCH_USER"
fi

# == delete alarm ==

if id "alarm" &>/dev/null; then
    info "Deleting alarm"
    userdel -r "alarm"
fi
