docker run --rm --privileged multiarch/qemu-user-static --reset -p yes

info 'Chrooting into installed system to continue setup...'
printline '-'

rsync -L -r -a \
     --exclude arch_root \
     --exclude *.tar.gz \
    "$ROOT_DIR/" arch_root/arch_install

arch-chroot arch_root /arch_install/install.sh chroot
