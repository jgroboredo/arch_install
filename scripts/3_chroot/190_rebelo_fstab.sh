#!/bin/bash

if [ "$ARCH_HOSTNAME" == 'rebelo-ge60' ]; then
    info "Sourcing post-install for $ARCH_HOSTNAME"

    {
    echo "# Storage HDD"
    echo "UUID=03102fba-b324-4aa2-8327-d4b13c4ccadd     /mnt/hdd1        ext4     defaults,nofail,noatime 0 0"
    echo ""
    echo "# Storage 1TB"
    echo "UUID=16CA3CE8514B0DF8                         /mnt/hdd2        ntfs-3g  defaults,nofail,uid=${ARCH_ADMIN_UID},gid=${ARCH_ADMIN_UID},dmask=077,fmask=177 0 0"
    } >> /etc/fstab
fi

if [[ "$ARCH_HOSTNAME" == rebelo-* ]]; then
    {
    echo ""
    echo "# External 6TB"
    echo "UUID=5cc7e254-07e8-40cb-ab14-a35809730d84     /mnt/usb6t       ext4     defaults,noauto,nofail,noatime 0 0"
    } >> /etc/fstab
fi


# paulo_http: /mnt/paulo fuse.rclonefs noauto,x-systemd.automount,_netdev,config=/home/jose/.config/rclone/rclone.conf,allow-other,uid=1995,gid=1995 0 0

# for zen:
# jose@pi:/ /mnt/rebelo-pi fuse.sshfs noauto,x-systemd.automount,_netdev,user,idmap=user,follow_symlinks,identityfile=/root/.ssh/id_rsa,allow_other,default_permissions,uid=1995,gid=1995,noatime,reconnect,ServerAliveInterval=45,ServerAliveCountMax=2 0 0
