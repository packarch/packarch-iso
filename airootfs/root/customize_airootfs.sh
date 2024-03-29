#!/usr/bin/env bash

## Script to perform several important tasks before `mkpackarchiso` create filesystem image.

set -e -u

## -------------------------------------------------------------- ##

# fr_FR.UTF-8 locales
sed -i 's/#\(fr_FR\.UTF-8\)/\1/' /etc/locale.gen
locale-gen

# France, Paris timezone
ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime

# No password for members of wheel
echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

## Fix Initrd Generation in Installed System
cat > "/etc/mkinitcpio.d/linux.preset" <<- _EOF_
	# mkinitcpio preset file for the 'linux' package

	ALL_kver="/boot/vmlinuz-linux"
	ALL_config="/etc/mkinitcpio.conf"

	PRESETS=('default' 'fallback')

	#default_config="/etc/mkinitcpio.conf"
	default_image="/boot/initramfs-linux.img"
	#default_options=""

	#fallback_config="/etc/mkinitcpio.conf"
	fallback_image="/boot/initramfs-linux-fallback.img"
	fallback_options="-S autodetect"
_EOF_

## -------------------------------------------------------------- ##

## Enable Parallel Downloads
sed -i -e 's|#ParallelDownloads.*|ParallelDownloads = 6|g' /etc/pacman.conf
sed -i -e '/#\[testing\]/Q' /etc/pacman.conf

## Append packarch repository to pacman.conf
cat >> "/etc/pacman.conf" <<- EOL
	[packarch]
	SigLevel = Optional TrustAll
	Include = /etc/pacman.d/packarch-mirrorlist

	#[testing]
	#Include = /etc/pacman.d/mirrorlist

	[core]
	Include = /etc/pacman.d/mirrorlist

	[extra]
	Include = /etc/pacman.d/mirrorlist

	#[community-testing]
	#Include = /etc/pacman.d/mirrorlist

	[community]
	Include = /etc/pacman.d/mirrorlist

	# If you want to run 32 bit applications on your x86_64 system,
	# enable the multilib repositories as required here.

	#[multilib-testing]
	#Include = /etc/pacman.d/mirrorlist

	[multilib]
	Include = /etc/pacman.d/mirrorlist

	# An example of a custom package repository.  See the pacman manpage for
	# tips on creating your own repositories.
	#[custom]
	#SigLevel = Optional TrustAll
	#Server = file:///home/custompkgs
EOL

## -------------------------------------------------------------- ##
## Add syno nfs share to autofs
sed -i -e 's|/misc.*|/mnt /etc/auto.nfs --ghost,--timeout=60|g' /etc/autofs/auto.master
systemctl enable autofs
## -------------------------------------------------------------- ##

## Copy Few Configs Into Root Dir
rdir="/root/.config"
sdir="/etc/skel"
if [[ ! -d "$rdir" ]]; then
	mkdir "$rdir"
fi

rconfig=(alacritty geany gtk-3.0 Kvantum leafpad libfm neofetch pcmanfm qt5ct Thunar xfce4)
for cfg in "${rconfig[@]}"; do
	if [[ -e "$sdir/.config/$cfg" ]]; then
		cp -rf "$sdir"/.config/"$cfg" "$rdir"
	fi
done

rcfg=('.local' '.oh-my-zsh' '.gtkrc-2.0' '.zshrc')
for cfile in "${rcfg[@]}"; do
	if [[ -e "$sdir/$cfile" ]]; then
		cp -rf "$sdir"/"$cfile" /root
	fi
done

## -------------------------------------------------------------- ##

## Don't launch welcome app on installed system, launch Help instead
sed -i -e '/## Welcome-App-Run-Once/Q' /etc/skel/.config/openbox/autostart
cat >> "/etc/skel/.config/openbox/autostart" <<- EOL
	## Help-App-Run-Once
	help-and-tips &
	sed -i -e '/## Help-App-Run-Once/Q' "\$HOME"/.config/openbox/autostart
EOL

## -------------------------------------------------------------- ##

## Set `Qogirr` as default cursor theme
sed -i -e 's|Inherits=.*|Inherits=Qogirr|g' /usr/share/icons/default/index.theme
mkdir -p /etc/skel/.icons && cp -rf /usr/share/icons/default /etc/skel/.icons/default

## Update xdg-user-dirs for bookmarks in thunar and pcmanfm
runuser -l liveuser -c 'xdg-user-dirs-update'
runuser -l liveuser -c 'xdg-user-dirs-gtk-update'
xdg-user-dirs-update
xdg-user-dirs-gtk-update

## Delete stupid gnome backgrounds
gndir='/usr/share/backgrounds/gnome'
if [[ -d "$gndir" ]]; then
	rm -rf "$gndir"
fi

## -------------------------------------------------------------- ##

## Hide Unnecessary Apps
adir="/usr/share/applications"
apps=(avahi-discover.desktop bssh.desktop bvnc.desktop echomixer.desktop \
	envy24control.desktop exo-preferred-applications.desktop feh.desktop \
	hdajackretask.desktop hdspconf.desktop hdspmixer.desktop hwmixvolume.desktop lftp.desktop \
	libfm-pref-apps.desktop lxshortcut.desktop lstopo.desktop \
	networkmanager_dmenu.desktop nm-connection-editor.desktop pcmanfm-desktop-pref.desktop \
	qv4l2.desktop qvidcap.desktop stoken-gui.desktop stoken-gui-small.desktop thunar-bulk-rename.desktop \
	thunar-settings.desktop thunar-volman-settings.desktop yad-icon-browser.desktop)

for app in "${apps[@]}"; do
	if [[ -e "$adir/$app" ]]; then
		sed -i '$s/$/\nNoDisplay=true/' "$adir/$app"
	fi
done

## -------------------------------------------------------------- ##

## Lightdm config (Greeter, Autologin)
lightdm_config='/etc/lightdm/lightdm.conf'
sed -i -e 's|#greeter-session=.*|greeter-session=lightdm-gtk-greeter|g' "$lightdm_config"
sed -i -e 's|#autologin-user=.*|autologin-user=liveuser|g' "$lightdm_config"
sed -i -e 's|#autologin-session=.*|autologin-session=openbox|g' "$lightdm_config"
sed -i -e 's|#greeter-setup-script=.*|greeter-setup-script=/usr/bin/numlockx on|g' "$lightdm_config"
groupadd -r autologin
gpasswd -a liveuser autologin
systemctl enable lightdm

## -------------------------------------------------------------- ##
