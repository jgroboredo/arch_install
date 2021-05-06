#!/bin/bash

set -euo pipefail  # x for debug

GIT_REV=$(git rev-parse --short HEAD)

cd "/home/jose/workspace/joserebelo.gitlab.io/" || exit 1

EXISTING_CHANGES=$(git status --porcelain=v1 2>/dev/null | wc -l)

if [ "$EXISTING_CHANGES" != '0' ]; then
    echo "There are '$EXISTING_CHANGES' local changes, can't deploy"
    exit 1
fi

git pull

echo "$GIT_REV" > "public/arch/version"

git submodule update --remote --merge
git commit -a -m "Update arch-install to $GIT_REV"
git push

DEPLOYED_GIT_REV='unknown'
while [ "$DEPLOYED_GIT_REV" != "$GIT_REV" ]; do
    echo "Deployed ($DEPLOYED_GIT_REV) differs from local ($GIT_REV)"
    sleep 2
    DEPLOYED_GIT_REV=$(curl -s https://joserebelo.gitlab.io/arch/version)
done
