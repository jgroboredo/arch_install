#!/bin/bash
# shellcheck disable=SC1090

set -euo pipefail  # x for debug

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

ARCH_CMD=''
TAG_FROM=''
TAG_ONLY=''

# Source common scripts
for s in "$ROOT_DIR/scripts/0_common"/*.sh; do
    source "$s"
done

# Check main option
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -f|--from) TAG_FROM="$2"; shift ;;
        -o|--only) TAG_ONLY="$2"; shift ;;
        *)         ARCH_CMD="$1"        ;;
    esac
    shift
done

case "$ARCH_CMD" in
    pc)     export SCRIPT_SUBDIR=2_pc     ;;
    pi)     export SCRIPT_SUBDIR=2_pi     ;;
    chroot) export SCRIPT_SUBDIR=3_chroot ;;
    scan) sudo arp-scan --localnet && exit 0 ;;
    *) fail "Unknown install option '$ARCH_CMD' (should be one of: pc, pi, chroot, scan)"; ;;
esac

if [ ! -f "$ROOT_DIR/config.sh" ]; then
    source "$ROOT_DIR/scripts/1_config/configurator.sh"
fi

source "$ROOT_DIR/config.sh"
source "$ROOT_DIR/passwords.sh"

echo
printline '-'

if [ ! -z "$TAG_FROM" ] || [ ! -z "$TAG_ONLY" ]; then
    TAG_RUNNING=false
else
    TAG_RUNNING=true
fi

# Run installer
for s in "$ROOT_DIR/scripts/$SCRIPT_SUBDIR"/*.sh; do
    SCRIPT_FILENAME=$(basename $s)
    TASK_NUM=$(basename $s | cut -d_ -f1)

    if [[ ! -z "$ARCH_TAG_LIST" ]] && [[ $ARCH_TAG_LIST != *$TASK_NUM* ]]; then
        info "Skipping [$TASK_NUM] $s"
        continue
    fi

    if [ "$TASK_NUM" == "$TAG_ONLY" ] || [ "$TASK_NUM" == "$TAG_FROM" ]; then
        TAG_RUNNING=true
    fi

    if [ "$TAG_RUNNING" == 'true' ]; then
        printline '='
        info "Sourcing '$s'"

        source "$s"

        if [ ! -z "$TAG_ONLY" ]; then
            break
        fi
    fi
done
