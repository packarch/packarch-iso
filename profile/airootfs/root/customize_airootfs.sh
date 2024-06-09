#!/usr/bin/env bash

## Script to perform several important tasks before `mkpackarchiso` create filesystem image.

set -e -u

## -------------------------------------------------------------- ##
# fr_FR.UTF-8 locales
sed -i 's/#\(fr_FR\.UTF-8\)/\1/' /etc/locale.gen
locale-gen

# France, Paris timezone
ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime

## Modify /etc/mkinitcpio.conf file
sed -i '/etc/mkinitcpio.conf' \
	-e "s/base udev/base udev plymouth/g" \
	-e "s/#COMPRESSION=\"zstd\"/COMPRESSION=\"zstd\"/g"

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
sed -i -e 's|#ParallelDownloads.*|ParallelDownloads = 5|g' /etc/pacman.conf
sed -i -e '/#\[core-testing\]/Q' /etc/pacman.conf

## Append packarch repository to pacman.conf
cat >> "/etc/pacman.conf" <<- EOL
	[packarch]
	SigLevel = Optional TrustAll
	Include = /etc/pacman.d/packarch-mirrorlist

	[core]
	Include = /etc/pacman.d/mirrorlist

	[extra]
	Include = /etc/pacman.d/mirrorlist
EOL

## -------------------------------------------------------------- ##

## Delete ISO specific init files
rm -rf /etc/mkinitcpio.conf.d
rm -rf /etc/mkinitcpio.d/linux-nvidia.preset

## -------------------------------------------------------------- ##
## Add syno nfs share to autofs
sed -i -e 's|/misc.*|/mnt /etc/auto.nfs --ghost,--timeout=60|g' /etc/autofs/auto.master
systemctl enable autofs.service

## -------------------------------------------------------------- ##

## Enable lightdm
gpasswd -a liveuser autologin
sed -i -e 's|#autologin-user=|autologin-user=liveuser|g'           /etc/lightdm/lightdm.conf
sed -i -e 's|#autologin-user-timeout=0|autologin-user-timeout=0|g' /etc/lightdm/lightdm.conf

sed -i -e 's|user-session=default|user-session=openbox|g' /etc/lightdm/lightdm.conf
sed -i -e 's|#greeter-session=example-gtk-gnome|greeter-session=lightdm-gtk-greeter|g' /etc/lightdm/lightdm.conf
sed -i -e 's|#theme-name=|theme-name=Juno-mirage|g' /etc/lightdm/lightdm-gtk-greeter.conf
systemctl enable lightdm.service

## Set zsh as default shell for new user
sed -i -e 's#SHELL=.*#SHELL=/bin/zsh#g' /etc/default/useradd

## -------------------------------------------------------------- ##

## Copy Few Configs Into Root Dir
rdir="/root/.config"
sdir="/etc/skel"
if [[ ! -d "$rdir" ]]; then
	mkdir "$rdir"
fi

rconfig=(geany gtk-3.0 Kvantum neofetch qt5ct qt6ct Thunar xfce4)
for cfg in "${rconfig[@]}"; do
	if [[ -e "$sdir/.config/$cfg" ]]; then
		cp -rf "$sdir"/.config/"$cfg" "$rdir"
	fi
done

rcfg=('.gtkrc-2.0' '.oh-my-zsh' '.zshrc')
for cfile in "${rcfg[@]}"; do
	if [[ -e "$sdir/$cfile" ]]; then
		cp -rf "$sdir"/"$cfile" /root
	fi
done

## -------------------------------------------------------------- ##

## Make it executable
chmod +x /etc/skel/.screenlayout/my-layout.sh

## Fix cursor theme
rm -rf /usr/share/icons/default

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



