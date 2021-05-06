#!/bin/bash

curl https://codeload.github.com/joserebelo/joserebelo.github.io/tar.gz/master | \
    tar xzvf - -C . --strip-components=2 joserebelo.github.io-master/arch

exit 0

ADDR="joserebelo.me/arch"

echo "Downloading arch-install from $ADDR"

#wget --recursive --level=0 --no-parent \
#    --reject="*.html*" \
#    --quiet \
#    "https://$ADDR/files.html"

while IFS= read -r f; do
    echo "$f"
    mkdir -p "${f%/*}"
    curl -s -f "https://$ADDR/$f" > "$f"
done <<< "$(curl -s -f "https://$ADDR/files.html")"

echo "Downloaded, setting executable"
find . -name "*.sh" -exec chmod +x "{}" \;
find . -name sxrc -exec chmod +x {} \;
