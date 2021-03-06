#!/bin/sh

# Fernando Carmona Varo <ferkiwi@gmail.com>

#----
# Script to download the full list of arch mirrors,
# test them and select the fastest ones.
#----

[ "$(id -ru)" != 0 ] && {
    sudo -l $0 >&- && sudo $0
    exit $?
}

TEMP=$(mktemp --suffix="-mirrorlist")

# Get the Official list of available mirrors
curl https://www.archlinux.org/mirrorlist/all/ -o "$TEMP"

# Uncomment them all
sed 's|^#||' -i "$TEMP"

# Rank mirrors according to their response time and save 
# the 10 fastest ones in the default mirrorlist
rankmirrors -n 10 "$TEMP" > /etc/pacman.d/mirrorlist


