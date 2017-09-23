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
HOSTNAME='gb-mbp'

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
      mkpart "/boot" fat16 1 512M \
      mkpart "/" ext4 512M 41G  \
      mkpart "swap" linux-swap 41G 73G \
      set 1 boot on \
      set 1 esp on

  parted -s "$user_dev" \
  		mklabel gpt \
  		mkpart "/home" ext4 1 500G
}

erase_drives() {
  local erase="$1"; shift
  local part="$1"; shift
  parted -s $erase rm $part
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

  umount /mnt/home
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

install_yaourt(){
  echo 'Installing needed packages...'
  pacman -S --needed --noconfirm git wget yajl
  if [[ -d __build ]]; then
    rm -rf __build
  fi
  mkdir __build
  cd __build
  git clone https://aur.archlinux.org/package-query.git
  cd package-query/
  makepkg -si
  cd ..
  git clone https://aur.archlinux.org/yaourt.git
  cd yaourt/
  makepkg -si
  cd ../..
  rm -rf __build
}

install_packages() {
  cd _custom_config_
  # create list of software not found in official repos
  comm -23 <(sort software.txt) <(pacman -Ssq | sort) >> software_not_installed.txt
  # create list of installed software
  comm -23 <(sort software.txt) <(sort software_not_installed.txt) >> software_installed.txt
  
  local packages=$(cat software_installed.txt | tr "\n" " ")

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
  cd ..
}

install_aur_packages() {
  cd _custom_config_
  # install software not in official repos
  local packages=$(cat software_not_installed.txt | tr "\n" " ")
	# android, install by AUR
	yaourt -S --noconfirm $packages
  cd ..
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

set_systemd() {
  bootctl --path=/boot install
  cp /_custom_config_/loader.conf /boot/loader/loader.conf
  cp /_custom_config_/arch.conf /boot/loader/entries/arch.conf
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

  useradd -m -s /bin/zsh -G wheel,adbusers "$name"
  echo -en "$password\n$password" | passwd "$name"
}

setup() {

  local script=$1; shift
  local cfgs=$1; shift

  local boot_dev="$DRIVE"1
  local root_dev="$DRIVE"2
  local swap_dev="$DRIVE"3
  local home_dev="$USER_DRIVE"1

  echo 'Setting time'
  timedatectl set-ntp true

  echo 'Erasing disks'
  erase_drives "$DRIVE" 1
  erase_drives "$DRIVE" 2
  erase_drives "$DRIVE" 3
  erase_drives "$USER_DRIVE" 1

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
  cp $script /mnt/setup.sh
  cp -r $cfgs /mnt/_custom_config_

  arch-chroot /mnt ./setup.sh chroot

  if [ ! -f /mnt/the_end ]
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

	set_modules_load

  echo 'Configuring initial ramdisk'
  mkinitcpio -p linux

  echo 'Configuring bootloader'
  set_systemd

  # echo 'Configuring lxdm'
  # set_lxdm

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

  sudo "$USER_NAME" -

  echo 'Installing yaourt'
  install_yaourt

  echo 'Installing AUR packages'
  install_aur_packages

  # rm /setup.sh
  # rm -rf /_custom_config_
  touch /the_end
  echo 'Dont forget to remove /setup.sh and /_custom_config_'
}

set -e

if [ "$1" == "chroot" ]
then
  configure
elif [[ "$@" -lt 1 ]]
then
  echo "Usage $0 <cfg_dir>"
else
  setup $0 $1
fi
