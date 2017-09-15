#!/bin/bash

# Taken from: https://github.com/tom5760/arch-install

## Minimum script to install arch linux

## Setup disks
## 	Current disks:
##		/dev/sda: 1TB HHD
## 		  | gpt partition table
## 			|-- 500GB /home
## 		/dev/sdb: 256 GB SSD
## 		  | gpt partition table
## 			|-- 512MB /boot (boot, esp)
## 			|-- 40GB /
## 			|-- 32GB SWAP (swap)

USER_DRIVE='/dev/sda'
DRIVE='/dev/sdb'

# Hostname of the installed machine.
HOSTNAME='gb-arch'

# System timezone.
TIMEZONE='Europe/Madrid'
KEYMAP='us'

ROOT_PASSWORD=''
USER_NAME='gb'
USER_PASSWORD=''

# Choose your video driver
# For Intel
VIDEO_DRIVER="i915"
# For nVidia
#VIDEO_DRIVER="nouveau"
# For ATI
#VIDEO_DRIVER="radeon"
# For generic stuff
#VIDEO_DRIVER="vesa"

partition_drives() {
  local dev="$1"; shift
  local user_dev="$1"; shift

  # 512 MB /boot partition (boot, esp flags)
  # 40 GB /root partition
  # 32 GB [SWAP] partition (swap flag)
  parted -s "$dev" \
      mklabel gpt \
      mkpart fat16 "/boot" 1 512M \
      mkpart ext4 "/" 512M 41G  \
      mkpart linux-swap "swap" 41G 73G \
      set 1 boot on \
      set 1 esp on \
      set 3 swap on

  parted -s "$user_dev" \
  		mklabel gpt \
  		mkpart ext4 "/home" 1 500G
}

erase_drives() {
  local $erase="$1"; shift
  parted -s $erase rm all
}

format_filesystems() {
	local boot_dev="$1"; shift
	local root_dev="$1"; shift
	local swap_dev="$1"; shift
	local home_dev="$1"; shift

	mkfs.fat -F 16 "$boot_dev"
	mkfs.ext4 -L root "$root_dev"
	mkswap "$swap_dev"

	mkfs.ext4 -L home "$home_dev"
}

mount_filesystems() {
  local boot_dev="$1"; shift
	local root_dev="$1"; shift
	local swap_dev="$1"; shift
  local home_dev="$1"; shift

  mount "$root_dev" /mnt
  mkdir /mnt/boot
  mount "$boot_dev" /mnt/boot
  swapon "$swap_dev"

  mkdir /mnt/home
  mount "$home_dev" /mnt/home
}

unmount_filesystems() {
	local swap_dev="$1"; shift

  umount /mnt/boot
  umount /mnt
  swapoff "$swap_dev"
}

install_base() {
  # Default list has all mirrors
  # ToDo =: Install reflector
  # echo 'Server = http://mirrors.kernel.org/archlinux/$repo/os/$arch'
  # >> /etc/pacman.d/mirrorlist

  pacstrap /mnt base base-devel
  pacstrap /mnt syslinux
}

gen_fstab() {

	genfstab -U /mnt >> /mnt/etc/fstab
}

install_packages() {
	local packages=''

	# General utilities/libraries
	packages+=' rsync sudo unrar unzip wget curl zip zsh oh-my-zsh-git cargo arandr docker gnome-disk-utility gnu-netcat gparted nmap numlockx scrot yaourt libnotify xfce4-terminal xfce4-notifyd xfce4-screenshooter thunar thunar-archive-plugin thunar-media-tags-plugin thunar-volman'
	# Java stuff
	packages+=' icedtea-web-java7 jdk7-openjdk jre7-openjdk'
	# Office
	packages+=' wps-office galculator-gtk2 gimp gitbook-editor'
	# Fonts
	packages+=' cantarell-fonts ttf-dejavu ttf-liberation'
	# On Intel processors
	packages+=' intel-ucode'
	# Dev
	packages+=' git gitkraken go gradle gulp vim sublime-text-dev python2 python2-pip python python-pip'
	# misc
	packages+=' filezilla firefox google-chrome gtk-recordmydesktop okular-git spotify synergy telegram-desktop viewnior virtualbox youtube-dl mendeleydesktop stremio-legacy vlc'
	# ui
	packages+=' feh i3-wm lxappearance lxdm lxdm-themes vertex-maia-icon-themes vertex-maia-themes polybar'
	
	if [ "$VIDEO_DRIVER" = "i915" ]
  then
      packages+=' xf86-video-intel' #libva-intel-driver
  elif [ "$VIDEO_DRIVER" = "nouveau" ]
  then
      packages+=' xf86-video-nouveau'
  elif [ "$VIDEO_DRIVER" = "radeon" ]
  then
      packages+=' xf86-video-ati'
  elif [ "$VIDEO_DRIVER" = "vesa" ]
  then
      packages+=' xf86-video-vesa'
  fi

  pacman -Sy --noconfirm $packages
}

install_aur_packages() {
	mkdir /foo
	export TMPDIR=/foo
	# android, install by AUR
	yaourt -S --noconfirm android-platform android-sdk-build-tools android-tools android-udev
	unset TMPDIR
	rm -rf /foo
}

clean_packages() {

	yes | pacman -Scc
}

set_hostname() {
  local hostname="$1"; shift

  echo "$hostname" > /etc/hostname
}

set_timezone() {
  local timezone="$1"; shift

  ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
  hwclock --systohc
}

set_locale() {
  echo "LC_MEASUREMENT=es_ES.UTF-8" >> /etc/locale.conf
	echo "LC_NUMERIC=es_ES.UTF-8" >> /etc/locale.conf
	echo "LC_PAPER=es_ES.UTF-8" >> /etc/locale.conf
	echo "LC_IDENTIFICATION=es_ES.UTF-8" >> /etc/locale.conf
	echo "LC_MONETARY=es_ES.UTF-8" >> /etc/locale.conf
	echo "LC_TIME=es_ES.UTF-8" >> /etc/locale.conf
	echo "LC_ADDRESS=es_ES.UTF-8" >> /etc/locale.conf
	echo "LC_NAME=es_ES.UTF-8" >> /etc/locale.conf
	echo "LANG=en_US.UTF-8" >> /etc/locale.conf
	echo "LC_TELEPHONE=es_ES.UTF-8" >> /etc/locale.conf

	echo "en_US.UTF-8 UTF-8  " >> /etc/locale.gen
	echo "es_ES.UTF-8 UTF-8 " >> /etc/locale.gen
  locale-gen
}

set_keymap() {
  echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf
}

set_hosts() {
	local hostname="$1"; shift

	cat > /etc/hosts <<EOF
127.0.0.1	localhost
127.0.1.1	$hostname
::1	localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF
}

set_modules_load() {
  echo 'microcode' > /etc/modules-load.d/intel-ucode.conf
}

set_syslinux() {
	cp /_custom_config_/syslinux.cfg /boot/syslinux/syslinux.cfg
}

set_sudoers() {
	cp /_custom_config_/sudoers /etc/sudoers
	chmod 440 /etc/sudoers
}

set_lxdm() {
	cp /_custom_config_/lxdm.conf /etc/lxdm/lxdm.conf
}

get_input(){
  local INPUT1="foo"
  local INPUT2="bar"
  local ph1="Enter a passphrase to encrypt the disk:"
  local ph2="Re-enter passphrase:"
  while [ $INPUT1 != $INPUT2 ]; do
    echo -n $ph1
    stty -echo
    read INPUT1
    stty echo
    echo ""
    echo -n $ph2
    stty -echo
    read INPUT2
    stty echo
    echo ""
    if [ $INPUT1 != $INPUT2 ]; then
      echo "Bad match!  Try again"
    fi
    if [ $INPUT1 = $INPUT2 ] ; then
      INPUT=$INPUT1
    fi
  done
}

set_root_password() {
  local password="$1"; shift

  echo -en "$password\n$password" | passwd
}

create_user() {
    local name="$1"; shift
    local password="$1"; shift

    useradd -m -s /bin/zsh -G adm,systemd-journal,wheel,games,network,video,audio,optical,floppy,storage,scanner,power,adbusers "$name"
    echo -en "$password\n$password" | passwd "$name"
}

setup() {
	local boot_dev="$1"1
	local root_dev="$1"2
	local swap_dev="$1"3
	local home_dev="$2"1

	echo 'Setting time'
	timedatectl set-ntp true

  echo 'Erasing disks'
  erase_drives "$DRIVE"
  erase_drives "$USER_DRIVE"

	echo 'Partitioning disks'
	partition_drives "$DRIVE" "$USER_DRIVE"

	echo 'Formatting filesystems'
	format_filesystems "$boot_dev" "$root_dev" "$swap_dev" "$home_dev"

	echo 'Mounting filesystems'
	mount_filesystems "$boot_dev" "$root_dev" "$swap_dev" "$home_dev"

	echo 'Installing base system'
  install_base

  echo 'Generating fstab'
  gen_fstab

  echo 'Chrooting into installed system to continue setup...'
  cp /deploy/setup.sh /mnt/setup.sh
  cp -r /deploy/cfgs /mnt/_custom_config_

  arch-chroot /mnt ./setup.sh chroot

  if [ -f /mnt/setup.sh ]
  then
    echo 'ERROR: Something failed inside the chroot, not unmounting filesystems so you can investigate.'
    echo 'Make sure you unmount everything before you try to run this script again.'
  else
    echo 'Unmounting filesystems'
    unmount_filesystems "$swap_dev"
    echo 'Done! Reboot system.'
	fi
}

configure() {
	echo 'Installing additional packages'
  install_packages

  echo 'Installing AUR packages'
  install_aur_packages

  echo 'Clearing package tarballs'
	clean_packages

	echo 'Setting hostname'
  set_hostname "$HOSTNAME"

  echo 'Setting timezone'
  set_timezone "$TIMEZONE"

  echo 'Setting locale'
  set_locale

  echo 'Setting console keymap'
  set_keymap

  echo 'Setting hosts file'
	set_hosts "$HOSTNAME"

	# set_modules_load

	# echo 'Configuring initial ramdisk'
  # mkinitcpio -p linux

  echo 'Configuring bootloader'
  set_syslinux

  echo 'Configuring sudo'
  set_sudoers

  echo 'Configuring slim'
  set_lxdm

  if [ -z "$ROOT_PASSWORD" ]
  then
    get_input
    ROOT_PASSWORD=$INPUT
  fi
  echo 'Setting root password'
  set_root_password "$ROOT_PASSWORD"

  if [ -z "$USER_PASSWORD" ]
  then
    get_input
    USER_PASSWORD=$INPUT
  fi

  echo 'Creating initial user'
  create_user "$USER_NAME" "$USER_PASSWORD"

  echo 'Building locate database'
  updatedb

  rm /setup.sh
  rm -rf /_custom_config_
}

set -e

if [ "$1" == "chroot" ]
then
    configure
else
    setup
fi
