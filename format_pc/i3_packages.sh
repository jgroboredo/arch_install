install_packages() {
    local packages=''

    # basic tools
    packages+=' sudo xorg networkmanager network-manager-applet dialog wpa_supplicant mtools dosfstools linux-headers pacman-contrib' 
    packages+=' bluez bluez-utils xdg-utils xdg-user-dirs git cmake expac'
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
    packages+=' i3 dmenu picom guake pcmanfm xautolock flameshot'

    # Login manager
    packages+=' lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings'

    # xfce4
    packages+=' xfce4-terminal xfce4-power-manager xfce4-notifyd'
    
    # Fonts
    packages+=' ttf-dejavu ttf-liberation noto-fonts otf-font-awesome'

    # Themes, wallpapers and related apps
    packages+=' papirus-icon-theme materia-gtk-theme lxappearance nitrogen archlinux-wallpaper arc-gtk-theme'
    #packages+=' python-pywal'

    #Automount usb devices
    packages+=' gvfs gvfs-afc gvfs-goa gvfs-google gvfs-gphoto2 gvfs-mtp gvfs-nfs gvfs-smb'

    #ZSH related
    packages+=' zsh zsh-theme-powerlevel10k zsh-syntax-highlighting zsh-completions'
    
    #Some tools (xrandr, net)
    packages+=' arandr autorandr fuse2 htop inetutils net-tools netctl ntfs-3g pdf2svg tlp unzip cpupower ntp xarchiver p7zip'

    #working tools
    packages+=' zathura zathura-pdf-poppler texlive-most lyx jupyter jupyterlab python-numpy python-matplotlib python-scipy inkscape texmaker texlive-langgreek tmux viewnior rsync evince'

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
        packages+=' intel-compute-runtime intel-gpu-tools intel-media-driver'

        packages+=' nvidia-dkms nvidia-settings nvidia-utils lib32-nvidia-utils libglvnd lib32-libglvnd'
        packages+=' libvdpau lib32-libvdpau opencl-nvidia'
    
    elif [ "$VIDEO_DRIVER" = "amd-nvidia" ]
    then
        packages+=' xf86-video-amdgpu'

        packages+=' nvidia-dkms nvidia-settings nvidia-utils lib32-nvidia-utils libglvnd lib32-libglvnd'
        packages+=' libvdpau lib32-libvdpau opencl-nvidia'

    elif [ "$VIDEO_DRIVER" = "intel-radeon" ]
    then
        packages+=' xf86-video-intel libva-intel-driver mesa lib32-mesa vulkan-intel lib32-vulkan-intel'
        packages+=' intel-compute-runtime intel-gpu-tools intel-media-driver'

        packages+=' mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon libva-mesa-driver lib32-libva-mesa-driver'
        packages+=' mesa-vdpau lib32-mesa-vdpau opencl-mesa radeontop'
    
    elif [ "$VIDEO_DRIVER" = "amd-radeon" ]
    then
        packages+=' xf86-video-amdgpu'

        packages+=' mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon libva-mesa-driver lib32-libva-mesa-driver'
        packages+=' mesa-vdpau lib32-mesa-vdpau opencl-mesa radeontop'
    
    elif [ "$VIDEO_DRIVER" = "amd" ]
    then
        packages+=' xf86-video-amdgpu mesa lib32-mesa'

    fi

    pacman -Sy --noconfirm $packages
}


