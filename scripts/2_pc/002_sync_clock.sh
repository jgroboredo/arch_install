#!/bin/bash

# == Sync clock ==

timedatectl set-ntp true
sleep 2

if ! timedatectl status | grep -q 'System clock synchronized: yes'; then
    fail "Failed to synchronize clock with NTP"
elif ! timedatectl status | grep -q 'NTP service: active'; then
    fail "Failed to synchronize clock with NTP"
else
    info 'Clock: Synchronized'
fi
