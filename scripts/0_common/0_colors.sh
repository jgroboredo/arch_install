#!/bin/bash
# shellcheck disable=SC2034

# https://gist.github.com/vratiu/9780109

# Reset
NOCOLOR="\033[0m"            # Text Reset

# Regular Colors
BLACK="\033[0;30m"           # Black
RED="\033[0;31m"             # Red
GREEN="\033[0;32m"           # Green
YELLOW="\033[0;33m"          # Yellow
BLUE="\033[0;34m"            # Blue
PURPLE="\033[0;35m"          # Purple
CYAN="\033[0;36m"            # Cyan
WHITE="\033[0;37m"           # White

# Bold
B_BLACK="\033[1;30m"         # Black
B_RED="\033[1;31m"           # Red
B_GREEN="\033[1;32m"         # Green
B_YELLOW="\033[1;33m"        # Yellow
B_BLUE="\033[1;34m"          # Blue
B_PURPLE="\033[1;35m"        # Purple
B_CYAN="\033[1;36m"          # Cyan
B_WHITE="\033[1;37m"         # White

# Underline
U_BLACK="\033[4;30m"         # Black
U_RED="\033[4;31m"           # Red
U_GREEN="\033[4;32m"         # Green
U_YELLOW="\033[4;33m"        # Yellow
U_BLUE="\033[4;34m"          # Blue
U_PURPLE="\033[4;35m"        # Purple
U_CYAN="\033[4;36m"          # Cyan
U_WHITE="\033[4;37m"         # White

# Background
BG_BLACK="\033[40m"          # Black
BG_RED="\033[41m"            # Red
BG_GREEN="\033[42m"          # Green
BG_YELLOW="\033[43m"         # Yellow
BG_BLUE="\033[44m"           # Blue
BG_PURPLE="\033[45m"         # Purple
BG_CYAN="\033[46m"           # Cyan
BG_WHITE="\033[47m"          # White

# High Intensity
I_BLACK="\033[0;90m"         # Black
I_RED="\033[0;91m"           # Red
I_GREEN="\033[0;92m"         # Green
I_YELLOW="\033[0;93m"        # Yellow
I_BLUE="\033[0;94m"          # Blue
I_PURPLE="\033[0;95m"        # Purple
I_CYAN="\033[0;96m"          # Cyan
I_WHITE="\033[0;97m"         # White

# Bold High Intensity
BI_BLACK="\033[1;90m"        # Black
BI_RED="\033[1;91m"          # Red
BI_GREEN="\033[1;92m"        # Green
BI_YELLOW="\033[1;93m"       # Yellow
BI_BLUE="\033[1;94m"         # Blue
BI_PURPLE="\033[1;95m"       # Purple
BI_CYAN="\033[1;96m"         # Cyan
BI_WHITE="\033[1;97m"        # White

# High Intensity backgrounds
BG_I_BLACK="\033[0;100m\]"   # Black
BG_I_RED="\033[0;101m"       # Red
BG_I_GREEN="\033[0;102m\]"   # Green
BG_I_YELLOW="\033[0;103m\]"  # Yellow
BG_I_BLUE="\033[0;104m"      # Blue
BG_I_PURPLE="\033[10;95m\]"  # Purple
BG_I_CYAN="\033[0;106m"      # Cyan
BG_I_WHITE="\033[0;107m\]"   # White
