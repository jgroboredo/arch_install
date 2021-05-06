#!/bin/bash

# == fstab ==

genfstab -U /mnt >> /mnt/etc/fstab
sed -i -r 's/,subvolid=[0-9]+//g' /mnt/etc/fstab

printline '-'

cat /mnt/etc/fstab

pause "Check the fstab"
