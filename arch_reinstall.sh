#!/bin/bash

# Fernando Carmona Varo <ferkiwi@gmail.com>

#-----
# Dirty script I use for doing some rutine setup tasks when
# installing and configuring a new archlinux install.
#
# Note: I still didn't use it much, probably needs some love
#----

GIT_CONFIG_REPO=git@github.com:Ferk/xdg_config.git

set -a

trap finish EXIT
finish() {
    if [ $? != 0 ]
    then
	echo "An error was found!! The script aborted"
    fi
}


if [ "$PACMAN_CMD" ]
then
    # Use whatever is specified as PACMAN_CMD without any further check
    PACMAN=$PACMAN_CMD
else
    PACMAN=$({ which yaourt || which packer || which pacman;} 2>/dev/null)
    [ -z "$PACMAN" ] && {
	echo "Can't find pacman package installer. Is your system Archlinux?"
	exit 1
    }
    
    if [ $PACMAN = "pacman" ]
    then
	echo "no AUR installer found, downloading packer"
	wget https://raw.github.com/keenerd/packer/master/packer && {
	    pacman -S jshon fakeroot
	    chmod +x /usr/bin/packer
	    PACMAN=/usr/bin/packer
	}
    fi
fi

######
#{{{ Function definitions
msg() {
	echo -e "\e[33m ** \e[36m$@\e[0m"
}

confirm() {
	echo "$@"
	echo  "Do you want to edit that? [yN]"
	read edit
	[ "$edit" = "N" ] && return
}

i() {
    for pkg in $@
    do
	if pacman -Si $pkg >/dev/null
	then
	    INSTALL_LIST="$INSTALL_LIST $pkg"
	else
	    BADPKG_LIST="$BADPKG_LIST $pkg"
	fi
    done
}

o() {
    printf "\n$@"
    echo "Do you want to install these packages? [Yn]"
    read edit
    { [ "$edit" = "n" ] || [ "$edit" = "N" ]; } && return
    INSTALL_LIST="$INSTALL_LIST $@"
}

i_install() {
    echo "Installing: $INSTALL_LIST"
#    $PACMAN --noconfirm --needed -S $INSTALL_LIST
    $PACMAN --noconfirm -S $INSTALL_LIST
    echo "Packages that would not be found for installation: $BADPKG_LIST"
}

#######################
#{{{ Execution

if [ "$(id -u)" != 0 ]
then
    echo "You need to be root to run this script"
    exit 1
fi

#####{{{ User set up (add the right groups)
if [ "$USER" = "root" ]
then
    echo "Enter username for the main user (empty for no user changes): "
    read USER
fi

if [ "$USER" ]
then
    id "$USER" || {
	echo "Create new user '$USER'? (yN):"
	read yn
	if [ $yn = y ]
	then
	    adduser $USER
	else
	    break
	fi
    }
    msg "Setting up groups for user \"$USER\""

# Group          Affected files      Purpose
G="$G adm"      # /var/log/*     Read access to log files in /var/log
G="$G audio"    # /dev/sound/*, /dev/snd/*, /dev/misc/rtc0   Access to sound hardware.
#G="$G avahi"    # ??
#G="$G bin"      # /usr/bin/*     Right to modify binaries only by root, but right to read or executed by anyone. (Please modify this for better understanding...)
#G="$G daemon"   # ??
G="$G dbus"     # /var/run/dbus
#G="$G disk"     # /dev/sda[1-9], /dev/sdb[1-9], /dev/hda[1-9], etc   Access to block devices not affected by other groups such as optical,floppy,storage.
G="$G floppy"   # /dev/fd[0-9]   Access to floppy drives.
G="$G ftp"      # /srv/ftp
G="$G games"    # /var/games     Access to some game software.
#G="$G gdm"      # ??
G="$G hal"      # /var/run/hald, /var/cache/hald
G="$G http"     # ??
G="$G kmem"     # /dev/port, /dev/mem, /dev/kmem
G="$G locate"   # /usr/bin/locate, /var/lib/locate, /var/lib/slocate, /var/lib/mlocate   Right to use updatedb command.
G="$G log"      # /var/log/*     Access to log files in /var/log,
G="$G lp"       # /etc/cups, /var/log/cups, /var/cache/cups, /var/spool/cups for printer hardware
#G="$G mem"      # ??
G="$G mail"     # /usr/bin/mail
G="$G network"  #    Right to change network settings such as when using a Networkmanager.
#G="$G nobody"   #    Unprivileged group.
G="$G optical"  # /dev/sr[0-9], /dev/sg[0-9]     Access to optical devices such as CD,CD-R,DVD,DVD-R.
G="$G power"    #    Right to use suspend utils.
#G="$G rfkill"   # ??
#G="$G root"     # /* -- ALL FILES!   Complete system administration and control (root, admin)
G="$G scanner"  # /var/lock/sane     Access to scanner hardware.
G="$G smmsp"    #    sendmail group
G="$G storage"  #    Access to removable drives such as USB harddrives,flash/jump drives,mp3 players.
#G="$G stb-admin" # ??
#G="$G sys"       #    Right to admin printers in CUPS.
#G="$G thinkpad"  # /dev/misc/nvram    Right for thinkpad users using tools such as tpb.
#G="$G tty"       # /dev/tty, /dev/vcc, /dev/vc, /dev/ptmx
G="$G users"     #    Standard users group.
G="$G uucp"      # /dev/ttyS[0-9] /dev/tts/[0-9]  USB devices, RS232 and serial ports.
G="$G video"     # /dev/fb/0, /dev/misc/agpgart   for video capture devices, DRI/3D hw acceleration.
G="$G wheel"     # to use sudo (setup with visudo), Also affected by PAM
# non-default Groups
G="$G ntp"              #
G="$G policykit"        #
G="$G camera"           # Access to Digital Cameras.
G="$G clamav"           # /var/lib/clamav/*, /var/log/clamav/*
G="$G networkmanager"   #  to connect wirelessly with Networkmanager.
G="$G vboxusers"        # /dev/vboxdrv to use Virtualbox software.
G="$G vmware"           #  to use VMware software.
G="$G games"            # Permission to write to /var/games
G="$G systemd-journal"

for i in $G
do
    sudo gpasswd -a $USER $i
done

msg "Groups for \"$USER\":"
groups $USER
fi

msg "Setting up locale"
ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime

msg "Signing trusted master keys"

pacman-key --init
pacman-key --populate archlinux &>/dev/null || echo "Error found"
pacman-key --refresh-keys

#############
##{{{ Package installation
msg "Installing packages"

## basic
i base base-devel linux-tools
i xorg xorg-apps xorg-fonts xorg-utils xorg-xsetroot
i net-tools wpa_supplicant ethtool rfkill
i sudo

## Language Tools
i dictd goldendict espeak google-translate
i dictd-gcide dictd-jargon dictd-vera #dictd-wn
i aspell aspell-es aspell-en aspell-de 
i hunspell-es hunspell-en hunspell-de # for loffice/chromium
i gettext
i espeak

## Fonts
i ttf-google-fonts-git ttf-freefont ttf-liberation proggyfonts terminus-font bdf-unifont ttf-raghu ttf-ipa-mona ttf-monapo otf-ipafont
i ttf-ms-fonts ttf-vista-fonts

## Multimedia Tools
i imagemagick sxiv gimp gimp-webp-bzr #asciiview
i audio-convert vorbis-tools flac lame ffmpeg sox
i mpv
i cmus #xmms2
i icat-git imlib2-webp-git
i hsetroot
i pitivi
i cdparanoia
i exfalso exiv2
i jpegoptim
i pulseaudio paprefs pavucontrol
i submarine

## Development Tools
i emacs vim gdb jed 
i automake cmake
i openssh x11-ssh-askpass git bzr subversion
i checkbashisms
i cscope ctags

## Misc Commandline Tools
#i tct # http://www.linux-mag.com/id/1889/
i ed lsof lsw ncdu lesspipe dtach dvtm moreutils xprintidle mlocate
i stderred-git #rmshit-git #screenfo
i atool unrar zip unzip unarj p7zip xz bzip2
i minicom
i pm-utils
i lm_sensors
i acpi

## Networking
i openssh keychain #gpg
i aircrack-ng

## Internet
i firefox chromium netsurf elinks
i chromium-libpdf chromium-pepper-flash
i google-talkplugin flashplugin
i rtorrent #transmission-gtk tucan-hg
i nmap gnu-netcat aircrack-ng 
i dnsmasq dnsutils netcfg wireless_tools wpa_supplicant wpa_actiond ifplugd
i curl
i youtube-dl

# eBooks/Documents
i fbreader
i evince
i pdfedit
i texlive-most

# Disk management and recovery utilities
i parted gparted ntfs-3g
i testdisk

## Desktop Environment related
i slock swarp dmenu dwm-sprinkles
i inotify-tools
i xorg-xmessage xosd beep xsel
i rxvt-unicode
i thunar thunar-archive-plugin
i xbindkeys xclip xsel xmacro
i mimeo xdg-utils-mimeo
i slim
i unagi

# IM
i pidgin finch irssi

## Games and other silly stuff
i fortune-mod cowsay bsd-games
i nethack stone-soup hydraslayer tintin moon-buggy bastet enigma curseofwar cavez-of-fear cataclysm-dda
i puzzles pychess
i cheese
i fceux zsnes-netplay

i_install
echo -e "\a"
[ -f /usr/bin/beep ] && { 
    sudo chmod 4755 /usr/bin/beep
    beep
}

dconf write /org/gnome/desktop/interface/gtk-key-theme "'Emacs'"

##################
################### this step after git is installed
msg "Fetching configuration files from $GIT_CONFIG_REPO"

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config/}"

if [ -d "$XDG_CONFIG_HOME/.git" ]; then
    cd $XDG_CONFIG_HOME
    git pull
else 
    if [ -d "$XDG_CONFIG_HOME" ]; then
	# Move the existing .config to backup it
	mv "$XDG_CONFIG_HOME" "${XDG_CONFIG_HOME}.old"
    fi
    mkdir -p $XDG_CONFIG_HOME
    git clone -q $GIT_CONFIG_REPO "$XDG_CONFIG_HOME"
fi && {
    "$XDG_CONFIG_HOME/symlinks.sh"
}

###################
msg "Successfully finished."
