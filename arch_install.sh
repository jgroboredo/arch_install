#!/bin/bash

# Drive to install to.
DRIVE='/dev/sda'

# Hostname of the installed machine (leave blank to be prompted).
HOSTNAME=''

# Root password (leave blank to be prompted).
ROOT_PASSWORD=''

# Main user to create (by default, added to wheel group, and others) (leave blank to be prompted).
USER_NAME=''

# The main user's password (leave blank to be prompted).
USER_PASSWORD=''

# System timezone.
TIMEZONE='Europe/Lisbon'

# Have /tmp on a tmpfs or not.  Leave blank to disable.
# Only leave this blank on systems with very little RAM.
TMP_ON_TMPFS='TRUE'

#KEYMAP='us'
KEYMAP='pt-latin1'

#swap_size(GB)
SWAP_SIZE='2'

# Choose your video driver
# For Intel
VIDEO_DRIVER="i915"

# For nVidia + intel
#VIDEO_DRIVER="intel-nvidia"

# For nVidia + amd
#VIDEO_DRIVER="amd-nvidia"

# For ATI + intel
#VIDEO_DRIVER="intel-radeon"

# For ATI + intel
#VIDEO_DRIVER="amd-radeon"

if [ -d /sys/firmware/efi ]; then
    BIOS_TYPE="uefi"
else
    BIOS_TYPE="bios"
fi 



setup() {
    local boot_dev="$DRIVE"1
    local swap_dev="$DRIVE"2
    local root_dev="$DRIVE"3 
    local bios="$BIOS_TYPE"

    echo 'Updating system clock'
    timedatectl set-ntp true

    echo 'Creating partitions'
    partition_drive "$DRIVE" "$bios"
    sleep 3

    echo 'Formatting filesystems'
    format_filesystems "$DRIVE" "$bios"

    echo 'Mounting filesystems'
    mount_filesystems "$DRIVE" 
    sleep 3

    echo 'Installing base system'
    install_base
    sleep 3

    echo 'Setting fstab'
    set_fstab
    sleep 3

    echo 'Chrooting into installed system to continue setup...'
    cp $0 /mnt/setup.sh
    arch-chroot /mnt ./setup.sh chroot

    if [ -f /mnt/setup.sh ]
    then
        echo 'ERROR: Something failed inside the chroot, not unmounting filesystems so you can investigate.'
        echo 'Make sure you unmount everything before you try to run this script again.'
    else
        echo 'Unmounting filesystems'
        unmount_filesystems
        echo 'Done! Reboot system.'
    fi
}

configure() {
    local DEVICE="$DRIVE"
    local boot_dev="$DRIVE"1
    local root_dev="$DRIVE"3
    local bios="$BIOS_TYPE"
    
    # uncommenting multilib line in pacman config
    pacman_enable_repo 'multilib'
    sed -i '/ParallelDownloads/s/^#//g' /etc/pacman.conf 

    if [ -z "$HOSTNAME" ]
    then
        echo 'Enter the hostname of the computer:'
        while true; do
            read -p "Hostname: " host_name
            echo
            read -p "Hostname (again): " host_name2
            echo
            [ "$host_name" = "$host_name2" ] && break
            echo "Inputs do not match"
        done
        HOSTNAME=$host_name
        stty echo
    fi 

    if [ -z "$USER_NAME" ]
    then
        echo 'Enter the username of the account:'
        while true; do
            read -p "Username: " user_name
            echo
            read -p "Username (again): " user_name2
            echo
            [ "$user_name" = "$user_name2" ] && break
            echo "Inputs do not match"
        done
        USER_NAME=$user_name
        stty echo
    fi 

    CPU_VENDOR=$(grep vendor /proc/cpuinfo | uniq)
    if echo "$CPU_VENDOR" | grep -q -i intel; then
        ARCH_CPU_BRAND='intel'
    elif echo "$CPU_VENDOR" | grep -q -i amd; then
        ARCH_CPU_BRAND='amd'
    else
        echo "Unrecognized CPU vendor $CPU_VENDOR"
    fi
    
    echo 'Setting hostname'
    set_hostname "$HOSTNAME"

    echo 'Setting timezone'
    set_timezone "$TIMEZONE"

    echo 'Setting locale'
    set_locale

    echo 'Setting console keymap'
    set_keymap

    echo 'Setting hosts file'
    set_hosts "$HOSTNAME"
    
    echo 'Installing additional packages'
    install_packages

    echo 'Clearing package tarballs'
    clean_packages

    echo 'Setting initial modules to load'
    set_modules_load

    echo 'Configuring initial ramdisk'
    set_initcpio

    echo 'Setting initial daemons'
    set_daemons "$TMP_ON_TMPFS"

    echo 'Configuring bootloader'
    set_grub "$bios" "$DEVICE"

    echo 'Configuring sudo'
    set_sudoers

    if [ -z "$ROOT_PASSWORD" ]
    then
        echo 'Enter the root password:'
        while true; do
            read -s -p "Password: " password
            echo
            read -s -p "Password (again): " password2
            echo
            [ "$password" = "$password2" ] && break
            echo "Please try again"
        done
        ROOT_PASSWORD=$password
        stty echo
    fi
    echo 'Setting root password'
    set_root_password "$ROOT_PASSWORD"

    if [ -z "$USER_PASSWORD" ]
    then
        echo "Enter the password for user $USER_NAME"
        while true; do
            read -s -p "Password: " password
            echo
            read -s -p "Password (again): " password2
            echo
            [ "$password" = "$password2" ] && break
            echo "Please try again"
        done
        USER_PASSWORD=$password
        stty echo
    fi
    echo 'Creating initial user'
    create_user "$USER_NAME" "$USER_PASSWORD"

    echo 'Building locate database'
    update_locate

    echo 'Installing yay and AUR packages'
    install_yay "$USER_NAME"

    echo 'Installing dotfiles'
    dot_files "$USER_NAME"

    rm /setup.sh
}

partition_drive() {
    local dev="$1"; shift
    local bios="$1"; shift 

    if [ "$bios" == "uefi" ]; then
        parted -s "$dev" \
            mklabel gpt \
            mkpart P1 'fat32' '1MiB' '550MiB' \
            mkpart P2 'linux-swap' '550MiB' "${SWAP_SIZE}550MiB" \
            mkpart P3 'ext4' "${SWAP_SIZE}550MiB" '100%' \
            set 1 esp on
    fi

    if [ "$bios" == "bios" ]; then
        parted -s "$dev" \
            mklabel msdos \
            mkpart primary 'ext4' '4MiB' '512MiB' \
            mkpart primary 'linux-swap' '550MiB' "${SWAP_SIZE}550MiB" \
            mkpart primary 'ext4' "${SWAP_SIZE}550MiB" '100%' \
            set 1 boot on
    fi

}

format_filesystems() {
    local drive="$1"; shift
    local bios="$1"; shift

    if [ "$bios" == "uefi" ]; then
        mkfs.fat -F32 "$drive"1
        mkfs.ext4 "$drive"3
        mkswap "$drive"2; swapon "$drive"2
    fi

    if [ "$bios" == "bios" ]; then
        mkfs.ext4 -L boot "$drive"1
        mkfs.ext4 "$drive"3
        mkswap "$drive"2; swapon "$drive"2
    fi
}

mount_filesystems() {
    local drive="$1"; shift

    mount "$drive"3 /mnt
    mkdir /mnt/boot
    mount "$drive"1 /mnt/boot
}

install_base() {
    echo 'Server = http://mirrors.kernel.org/archlinux/$repo/os/$arch' >> /etc/pacman.d/mirrorlist

    pacstrap /mnt base base-devel linux linux-firmware vim
}

unmount_filesystems() {
    umount -a
}

pacman_enable_repo() {
    sed -i "/\[$1\]/,/Include/"'s/^#//' /etc/pacman.conf
}


install_packages() {
    local packages=''

    # basic tools
    packages+=' sudo xorg networkmanager network-manager-applet dialog wpa_supplicant mtools dosfstools linux-headers' 
    packages+=' bluez bluez-utils xdg-utils xdg-user-dirs git reflector cmake expac'
    packages+=' mlocate sshfs neofetch'
    
    #audio
    packages+=' pulseaudio pavucontrol alsa-utils pulseaudio-bluetooth'

    #video
    packages+=' mpv'

    #browser
    packages+=' chromium firefox'

    #grub related
    packages+=' grub efibootmgr os-prober'

    # Libreoffice
    packages+=' libreoffice-fresh hyphen-en mythes-en'
    
    # i3
    packages+=' i3 dmenu lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings picom guake pcmanfm xautolock flameshot'

    # xfce4
    packages+=' xfce4-terminal xfce4-power-manager xfce4-notifyd'
    
    # Fonts
    packages+=' ttf-dejavu ttf-liberation noto-fonts otf-font-awesome'

    # Themes, wallpapers and related apps
    packages+=' papirus-icon-theme materia-gtk-theme lxappearance nitrogen archlinux-wallpaper'

    #Automount usb devices
    packages+=' gvfs gvfs-afc gvfs-goa gvfs-google gvfs-gphoto2 gvfs-mtp gvfs-nfs gvfs-smb'

    #ZSH related
    packages+=' zsh zsh-theme-powerlevel10k zsh-syntax-highlighting zsh-completions'
    
    #Some tools (xrandr, net)
    packages+=' arandr autorandr fuse2 htop inetutils net-tools netctl ntfs-3g pdf2svg tlp unzip cpupower ntp xarchiver p7zip'

    #working tools
    packages+=' zathura zathura-pdf-poppler texlive-most lyx jupyter jupyterlab python-numpy python-matplotlib inkscape texmaker texlive-langgreek tmux viewnior rsync python-pywal evince'

    #dictionaries
    packages+=' nuspell hspell libvoikko hunspell-en_US'

    #thumbnails
    packages+=' tumbler poppler-glib ffmpegthumbnailer freetype2 raw-thumbnailer libgsf libgepub'

    # microcode for cpus
    packages+=" ${ARCH_CPU_BRAND}-ucode"

    # For laptops
    packages+=' xf86-input-libinput'

    # Gpu
    if [ "$VIDEO_DRIVER" = "i915" ]
    then
        packages+=' xf86-video-intel libva-intel-driver mesa lib32-mesa vulkan-intel lib32-vulkan-intel'
        packages+=' intel-compute-runtime intel-gpu-tools intel-media-driver'

    elif [ "$VIDEO_DRIVER" = "intel-nvidia" ]
    then
        packages+=' xf86-video-intel libva-intel-driver mesa lib32-mesa vulkan-intel lib32-vulkan-intel'
        packages+=' intel-compute-runtime intel-gpu-tools'

        packages+=' nvidia-dkms nvidia-settings nvidia-utils lib32-nvidia-utils libglvnd lib32-libglvnd'
        packages+=' libvdpau lib32-libvdpau opencl-nvidia'
    
    elif [ "$VIDEO_DRIVER" = "amd-nvidia" ]
    then
        packages+=' nvidia-dkms nvidia-settings nvidia-utils lib32-nvidia-utils libglvnd lib32-libglvnd'
        packages+=' libvdpau lib32-libvdpau opencl-nvidia'

    elif [ "$VIDEO_DRIVER" = "intel-radeon" ]
    then
        packages+=' xf86-video-intel libva-intel-driver mesa lib32-mesa vulkan-intel lib32-vulkan-intel'
        packages+=' intel-compute-runtime intel-gpu-tools'

        packages+=' mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon libva-mesa-driver lib32-libva-mesa-driver'
        packages+=' mesa-vdpau lib32-mesa-vdpau opencl-mesa radeontop'
    
    elif [ "$VIDEO_DRIVER" = "amd-radeon" ]
    then
        packages+=' mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon libva-mesa-driver lib32-libva-mesa-driver'
        packages+=' mesa-vdpau lib32-mesa-vdpau opencl-mesa radeontop'

    fi

    pacman -Sy --noconfirm $packages
}

clean_packages() {
    yes | pacman -Scc
}

set_hostname() {
    local hostname="$1"; shift

    echo "$hostname" > /etc/hostname
}

set_timezone() {
    local timezone="$1"; shift

    ln -sT "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
    hwclock --systohc
}

set_locale() {
    echo 'LANG="en_US.UTF-8"' >> /etc/locale.conf
    echo 'LC_COLLATE="C"' >> /etc/locale.conf
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
    echo "pt_PT.UTF-8 UTF-8" >> /etc/locale.gen
    locale-gen
}

set_keymap() {
    echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf
}

set_hosts() {
    local hostname="$1"; shift

    cat > /etc/hosts <<EOF
127.0.0.1 localhost
::1       localhost
127.0.1.1 $hostname.localdomain $hostname
EOF
}

set_fstab() {
    genfstab -U /mnt >> /mnt/etc/fstab
}

set_modules_load() {
    echo 'microcode' > /etc/modules-load.d/intel-ucode.conf
}

set_initcpio() {
    local vid

    if [ "$VIDEO_DRIVER" = "i915" ]
    then
        vid='i915'
    elif [ "$VIDEO_DRIVER" = "intel-nvidia" ]
    then
        vid='nvidia nvidia_modeset nvidia_uvm nvidia_drm'
    elif [ "$VIDEO_DRIVER" = "amd-nvidia" ]
    then
        vid='nvidia'
    elif [ "$VIDEO_DRIVER" = "intel-radeon" ]
    then
        vid='radeon'
    elif [ "$VIDEO_DRIVER" = "amd-radeon" ]
    then
        vid='radeon'
    fi

    # Set MODULES with your video driver
    cat > /etc/mkinitcpio.conf <<EOF
# vim:set ft=sh
# MODULES
# The following modules are loaded before any boot hooks are
# run.  Advanced users may wish to specify all system modules
# in this array.  For instance:
#     MODULES="piix ide_disk reiserfs"
MODULES="ext4 $vid"

# BINARIES
# This setting includes any additional binaries a given user may
# wish into the CPIO image.  This is run last, so it may be used to
# override the actual binaries included by a given hook
# BINARIES are dependency parsed, so you may safely ignore libraries
BINARIES=""

# FILES
# This setting is similar to BINARIES above, however, files are added
# as-is and are not parsed in any way.  This is useful for config files.
# Some users may wish to include modprobe.conf for custom module options
# like so:
#    FILES="/etc/modprobe.d/modprobe.conf"
FILES=""

# HOOKS
# This is the most important setting in this file.  The HOOKS control the
# modules and scripts added to the image, and what happens at boot time.
# Order is important, and it is recommended that you do not change the
# order in which HOOKS are added.  Run 'mkinitcpio -H <hook name>' for
# help on a given hook.
# 'base' is _required_ unless you know precisely what you are doing.
# 'udev' is _required_ in order to automatically load modules
# 'filesystems' is _required_ unless you specify your fs modules in MODULES
# Examples:
##   This setup specifies all modules in the MODULES setting above.
##   No raid, lvm2, or encrypted root is needed.
#    HOOKS="base"
#
##   This setup will autodetect all modules for your system and should
##   work as a sane default
#    HOOKS="base udev autodetect pata scsi sata filesystems"
#
##   This is identical to the above, except the old ide subsystem is
##   used for IDE devices instead of the new pata subsystem.
#    HOOKS="base udev autodetect ide scsi sata filesystems"
#
##   This setup will generate a 'full' image which supports most systems.
##   No autodetection is done.
#    HOOKS="base udev pata scsi sata usb filesystems"
#
##   This setup assembles a pata mdadm array with an encrypted root FS.
##   Note: See 'mkinitcpio -H mdadm' for more information on raid devices.
#    HOOKS="base udev pata mdadm encrypt filesystems"
#
##   This setup loads an lvm2 volume group on a usb device.
#    HOOKS="base udev usb lvm2 filesystems"
#
##   NOTE: If you have /usr on a separate partition, you MUST include the
#    usr, fsck and shutdown hooks.
HOOKS="base udev autodetect modconf block keymap keyboard resume filesystems fsck"

# COMPRESSION
# Use this to compress the initramfs image. By default, gzip compression
# is used. Use 'cat' to create an uncompressed image.
#COMPRESSION="gzip"
#COMPRESSION="bzip2"
#COMPRESSION="lzma"
#COMPRESSION="xz"
#COMPRESSION="lzop"

# COMPRESSION_OPTIONS
# Additional options for the compressor
#COMPRESSION_OPTIONS=""
EOF

    mkinitcpio -p linux
}

set_daemons() {
    local tmp_on_tmpfs="$1"; shift

    systemctl daemon-reload
    systemctl enable cpupower.service ntpd.service
    systemctl enable NetworkManager
    systemctl enable bluetooth
    systemctl enable fstrim.timer
    systemctl enable tlp.service
    systemctl enable lightdm

    if [ -z "$tmp_on_tmpfs" ]
    then
        systemctl mask tmp.mount
    fi
}

set_grub() {
    local bios="$1"; shift 
    local device="$1"; shift 
    
    if [ "$bios" == "uefi" ]; then 
        grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
        grub-mkconfig -o /boot/grub/grub.cfg
    fi

    if [ "$bios" == "bios" ]; then 
        grub-install --target=i386-pc --recheck $device 
        grub-mkconfig -o /boot/grub/grub.cfg
    fi
}

set_sudoers() {
    cat > /etc/sudoers <<EOF
## sudoers file.
##
## This file MUST be edited with the 'visudo' command as root.
## Failure to use 'visudo' may result in syntax or file permission errors
## that prevent sudo from running.
##
## See the sudoers man page for the details on how to write a sudoers file.
##

##
## Host alias specification
##
## Groups of machines. These may include host names (optionally with wildcards),
## IP addresses, network numbers or netgroups.
# Host_Alias	WEBSERVERS = www1, www2, www3

##
## User alias specification
##
## Groups of users.  These may consist of user names, uids, Unix groups,
## or netgroups.
# User_Alias	ADMINS = millert, dowdy, mikef

##
## Cmnd alias specification
##
## Groups of commands.  Often used to group related commands together.
# Cmnd_Alias	PROCESSES = /usr/bin/nice, /bin/kill, /usr/bin/renice, \
# 			    /usr/bin/pkill, /usr/bin/top

##
## Defaults specification
##
## You may wish to keep some of the following environment variables
## when running commands via sudo.
##
## Locale settings
# Defaults env_keep += "LANG LANGUAGE LINGUAS LC_* _XKB_CHARSET"
##
## Run X applications through sudo; HOME is used to find the
## .Xauthority file.  Note that other programs use HOME to find   
## configuration files and this may lead to privilege escalation!
# Defaults env_keep += "HOME"
##
## X11 resource path settings
# Defaults env_keep += "XAPPLRESDIR XFILESEARCHPATH XUSERFILESEARCHPATH"
##
## Desktop path settings
# Defaults env_keep += "QTDIR KDEDIR"
##
## Allow sudo-run commands to inherit the callers' ConsoleKit session
# Defaults env_keep += "XDG_SESSION_COOKIE"
##
## Uncomment to enable special input methods.  Care should be taken as
## this may allow users to subvert the command being run via sudo.
# Defaults env_keep += "XMODIFIERS GTK_IM_MODULE QT_IM_MODULE QT_IM_SWITCHER"
##
## Uncomment to enable logging of a command's output, except for
## sudoreplay and reboot.  Use sudoreplay to play back logged sessions.
# Defaults log_output
# Defaults!/usr/bin/sudoreplay !log_output
# Defaults!/usr/local/bin/sudoreplay !log_output
# Defaults!/sbin/reboot !log_output

##
## Runas alias specification
##

##
## User privilege specification
##
root ALL=(ALL) ALL

## Uncomment to allow members of group wheel to execute any command
%wheel ALL=(ALL) ALL

## Same thing without a password
# %wheel ALL=(ALL) NOPASSWD: ALL

## Uncomment to allow members of group sudo to execute any command
# %sudo ALL=(ALL) ALL

## Uncomment to allow any user to run sudo if they know the password
## of the user they are running the command as (root by default).
# Defaults targetpw  # Ask for the password of the target user
# ALL ALL=(ALL) ALL  # WARNING: only use this together with 'Defaults targetpw'

%rfkill ALL=(ALL) NOPASSWD: /usr/sbin/rfkill
%network ALL=(ALL) NOPASSWD: /usr/bin/netcfg, /usr/bin/wifi-menu

## Read drop-in files from /etc/sudoers.d
## (the '#' here does not indicate a comment)
#includedir /etc/sudoers.d
EOF

    chmod 440 /etc/sudoers
}

set_root_password() {
    local password="$1"; shift

    echo -en "$password\n$password" | passwd
}

create_user() {
    local name="$1"; shift
    local password="$1"; shift

    useradd -m -s /bin/zsh -G adm,systemd-journal,wheel,rfkill,games,network,video,audio,optical,floppy,storage,scanner,power "$name"
    echo -en "$password\n$password" | passwd "$name"
}

install_yay() {
    local ARCH_AUR_HELPER="yay"
    local ARCH_ADMIN="$1"; shift
    local packages=''

    if [ "$ARCH_AUR_HELPER" == 'none' ]; then
        echo '-'
        echo "Skipping AUR helper"
        echo '-'
    else
        echo '-'
        echo "Installing AUR helper '$ARCH_AUR_HELPER'"
        echo '-'

        AUR_HELPER_CLONE_DIR=/home/$ARCH_ADMIN/.cache/arch-install/aur_helper
        su -P "$ARCH_ADMIN" -c "mkdir -p $AUR_HELPER_CLONE_DIR"
        su -P "$ARCH_ADMIN" -c "cd $AUR_HELPER_CLONE_DIR; git clone https://aur.archlinux.org/$ARCH_AUR_HELPER.git"
        su -P "$ARCH_ADMIN" -c "cd $AUR_HELPER_CLONE_DIR/$ARCH_AUR_HELPER; makepkg -s"
        pacman --noconfirm -U "$AUR_HELPER_CLONE_DIR/$ARCH_AUR_HELPER/$ARCH_AUR_HELPER"*.pkg.tar*

        if [ -f "/etc/paru.conf" ]; then
            sed -i 's/^#BottomUp/BottomUp/' /etc/paru.conf
            sed -i 's/^#NewsOnUpgrade/NewsOnUpgrade/' /etc/paru.conf
        fi

        packages+=' acpi clipit ttf-font-awesome hamsket-bin polkit-gnome pa-applet-git pop-gtk-theme-git pop-icon-theme-git'
        packages+=' vim-plug-git vim-youcompleteme-git visual-studio-code-bin zoom hunspell-pt_pt textext qtgrace dmenu-extended fzwal-git mimeo xdg-utils-mimeo'

        # == install packages from AUR ==
        su -P "$ARCH_ADMIN" -c "$ARCH_AUR_HELPER -S $packages"
    fi

}

dot_files() {
    local ARCH_ADMIN="$1"; shift

    DOTFILES_CLONE_DIR=/home/$ARCH_ADMIN/Documents
    su -P "$ARCH_ADMIN" -c "mkdir -p $DOTFILES_CLONE_DIR"
    ZSHAUTO_CLONE_DIR=/home/$ARCH_ADMIN/.config

    #Creating vim pluggins directory
    su -P "$ARCH_ADMIN" -c "mkdir -p /home/$ARCH_ADMIN/.vim/plugged"
    
    #Creating cache directory for zsh
    su -P "$ARCH_ADMIN" -c "mkdir -p /home/$ARCH_ADMIN/.cache/zsh"
    su -P "$ARCH_ADMIN" -c "cd /home/$ARCH_ADMIN/.cache/zsh; touch dirs"

    #Creating lyx config folder
    su -P "$ARCH_ADMIN" -c "mkdir -p /home/$ARCH_ADMIN/.lyx"
        
    #Cloning needed repositories
    su -P "$ARCH_ADMIN" -c "cd $ZSHAUTO_CLONE_DIR; git clone https://github.com/zsh-users/zsh-autosuggestions.git"
    su -P "$ARCH_ADMIN" -c "cd $DOTFILES_CLONE_DIR; git clone https://github.com/jgroboredo/lap_dotfiles.git"

    #Installing dotfiles
    su -P "$ARCH_ADMIN" -c "cd $DOTFILES_CLONE_DIR/lap_dotfiles; sudo chmod +x install_bin.sh; sudo ./install_bin.sh"

    su -P "$ARCH_ADMIN" -c "cd $DOTFILES_CLONE_DIR/lap_dotfiles; sudo chmod +x install_dotfiles.sh; ./install_dotfiles.sh"

    su -P "$ARCH_ADMIN" -c "cd $DOTFILES_CLONE_DIR/lap_dotfiles/grub_theme; sudo chmod +x install.sh; sudo ./install.sh"

    su -P "$ARCH_ADMIN" -c "cd $DOTFILES_CLONE_DIR/lap_dotfiles/lyx; sudo chmod +x install_lyx_conf.sh; ./install_lyx_conf.sh"
    
    #Applying wal theme
    su -P "$ARCH_ADMIN" -c "wal --theme base16-nord"

    #Installing vim pluggins
    su -P "$ARCH_ADMIN" -c "vim +'PlugInstall --sync' +qa"
}


update_locate() {
    updatedb
}

get_uuid() {
    blkid -o export "$1" | grep UUID | awk -F= '{print $2}'
}

set -ex

if [ "$1" == "chroot" ]
then
    configure
else
    setup
fi
