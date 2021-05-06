#!/bin/bash

printline '='
pause 'All done in chroot'
touch /arch_install/success

if ask "Open bash in chroot before leaving?" N; then
    bash
fi

# Override resolv.conf for dnscrypt-proxy
# We can't do this in the dotfiles or we'll lose network connection
if [ "$(command -v dnscrypt-proxy)" ]; then
    echo 'nameserver 127.0.0.1' > /etc/resolv.conf
fi

shred "$ROOT_DIR/passwords.sh"
