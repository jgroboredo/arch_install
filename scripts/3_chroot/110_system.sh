#!/bin/bash

# == Temporary dns ==
echo 'nameserver 1.1.1.1' > /etc/resolv.conf

# == Timezone, locale and language ==

ln -sf /usr/share/zoneinfo/Europe/Lisbon /etc/localtime
hwclock --systohc

if [ "$ARCH_LANG" == 'en' ]; then
    ARCH_LOCALE='en_US'
elif [ "$ARCH_LANG" == 'pt' ]; then
    ARCH_LOCALE='pt_PT'
else
    fail "Unknown lang '$ARCH_LANG'"
fi

sed -i "s/^#\(pt_PT.UTF-8\)/\1/" /etc/locale.gen
sed -i "s/^#\($ARCH_LOCALE.UTF-8\)/\1/" /etc/locale.gen

locale-gen

echo "LANG=$ARCH_LOCALE.UTF-8" > /etc/locale.conf
echo 'KEYMAP=pt-latin9' > /etc/vconsole.conf
echo "$ARCH_HOSTNAME" > /etc/hostname
echo "Welcome to $ARCH_HOSTNAME!" > /etc/motd

cat > /etc/hosts <<EOF
127.0.0.1   localhost $ARCH_HOSTNAME
::1         localhost $ARCH_HOSTNAME
EOF

# == Pacman ==

function pacman_enable_repo () {
    sed -i "/\[$1\]/,/Include/"'s/^#//' /etc/pacman.conf
}

pacman_enable_repo 'multilib'

if [ "$ARCH_TESTING" == 'yes' ]; then
    pacman_enable_repo 'testing'
    pacman_enable_repo 'community-testing'
    pacman_enable_repo 'multilib-testing'
fi

sed -i 's/^# *\(Color\)/\1/' /etc/pacman.conf
sed -i 's/^# *\(TotalDownload\)/\1/' /etc/pacman.conf
sed -E -i "s/^PKGEXT=.*/PKGEXT='.pkg.tar'/" /etc/makepkg.conf
sed -E -i "s/^#MAKEFLAGS=.*/MAKEFLAGS='-j$(nproc)'/" /etc/makepkg.conf
sed -E -i 's/^(BUILDENV.+)\ !ccache (.+)/\1 ccache \2/'

# NoExtract = usr/share/dbus-1/accessibility-services/org.a11y.*
# sudo rm /usr/share/dbus-1/accessibility-services/org.a11y.*
