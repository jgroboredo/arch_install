#!/bin/zsh

if [ "$(command -v sx)" ] && [[ ! $DISPLAY && $XDG_VTNR -eq 1 ]]; then
    exec sx startplasma-x11
fi
