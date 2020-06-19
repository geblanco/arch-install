#!/bin/bash

# Taken from: https://github.com/tom5760/arch-install

## Minimum script to install arch linux

# Hostname of the installed machine.
HOSTNAME='gb'

# System timezone.
TIMEZONE='Europe/Madrid'
KEYMAP='es'

ROOT_PASSWORD=''
USER_NAME='gb'
USER_SHELL='zsh'
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

unmount_filesystems() {
  umount -R /mnt

  if [[ "$@" -eq 1 ]]; then
    swapoff $1
  fi
}

gen_fstab() {

  genfstab -U /mnt >> /mnt/etc/fstab
}

install_base() {
  # Default list has all mirrors
  # ToDo =: Install reflector
  # echo 'Server = http://mirrors.kernel.org/archlinux/$repo/os/$arch'
  # >> /etc/pacman.d/mirrorlist

  # if using another bootloader different from systemd,
  # this is the place to install it, pass it to pacstrap
  pacstrap /mnt base base-devel linux linux-firmware
  # not needed, using systemd (which comes in base-devel)
  # pacstrap /mnt syslinux
}

install_yaourt(){
  echo 'Installing needed packages...'
  pacman -S --needed --noconfirm git wget
  if [[ -d __build ]]; then
    rm -rf __build
  fi
  sudo -i -u $USER_NAME bash << EOF
mkdir __build
cd __build
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si --noconfirm
cd ../..
rm -rf __build
EOF
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
  yay -Suuya --noconfirm
  local packages=$(cat software_not_installed.txt | tr "\n" " ")
  yay -S --sudoloop --save --noconfirm $packages
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
  echo "LANG=en_GB.UTF-8" >> /etc/locale.conf
  echo "LANGUAGE=en_GB.UTF-8" >> /etc/locale.conf
  echo "LC_CTYPE=en_GB.UTF-8" >> /etc/locale.conf

  echo "en_US.UTF-8 UTF-8 " >> /etc/locale.gen
  echo "en_GB.UTF-8 UTF-8 " >> /etc/locale.gen
  echo "es_ES.UTF-8 UTF-8 " >> /etc/locale.gen
  locale-gen
}

set_keymap() {
  local map="$1"; shift

  echo "KEYMAP=$map" > /etc/vconsole.conf
}

set_hosts() {
	local hostname="$1"; shift

	cat > /etc/hosts <<EOF
127.0.0.1 ${hostname}.lsi.uned.es localhost
::1 ${hostname}.lsi.uned.es ${hostname} localhost
EOF
}

set_modules_load() {

  echo 'microcode' > /etc/modules-load.d/intel-ucode.conf
}

set_bootloader() {
  # if using a bootloader different from systemd this is the place to invoke it and copy it's config files
  bootctl --path=/boot install
  cp /_custom_config_/loader.conf /boot/loader/loader.conf
  cp /_custom_config_/arch.conf /boot/loader/entries/arch.conf
  # grub-install --target=i386-pc /dev/sda
  # grub-mkconfig -o /boot/grub/grub.cfg
}

set_root_password() {
  local password="$1"; shift

  echo -en "$password\n$password" | passwd
}

get_input(){
  INPUT=""
  local prompt="$1"; shift
  local INPUT1="foo"
  local INPUT2="bar"
  local ph1="Enter a password for '$prompt' user: "
  local ph2="Re-enter password for '$prompt' user: "
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

create_user() {
  local name="$1"; shift
  local password="$1"; shift

  mkdir -p /etc/skel/{Desktop,Documents,Downloads}
  useradd -m -s $(which $USER_SHELL) -G wheel "$name"
  echo -en "$password\n$password" | passwd "$name"
  # enable wheel as sudo
  sed 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/g' /etc/sudoers > ./sudoers
  mv ./sudoers /etc/sudoers
}

setup() {

  local script=$1; shift
  local cfgs=$1; shift
  local disker=$1; shift

  echo 'Setting time'
  timedatectl set-ntp true

  ./$disker
  if [[ $? -ne 0 ]]; then
    echo 'ERROR: Something failed inside the disk utility.'
    exit
  fi

  echo 'Installing base system'
  install_base

  echo 'Generating fstab'
  gen_fstab

  echo 'Chrooting into installed system to continue setup...'
  cp $script /mnt/setup.sh
  cp -r $cfgs /mnt/_custom_config_

  # the chrooted execution should setup the rest and create /mnt/the_end file
  arch-chroot /mnt ./setup.sh "chroot"

  if [ ! -f /mnt/the_end ]
  then
    echo 'ERROR: Something failed inside the chroot, not unmounting filesystems so you can investigate.'
    echo 'Make sure you unmount everything before you try to run this script again (umount -R /mnt)'
  else
    echo 'Unmounting filesystems'
    rm /mnt/the_end
    unmount_filesystems
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
  set_keymap "$KEYMAP"

  echo 'Setting hosts file'
	set_hosts "$HOSTNAME"

	set_modules_load

  echo 'Configuring initial ramdisk'
  mkinitcpio -p linux

  echo 'Configuring bootloader'
  set_bootloader

  if [ -z "$ROOT_PASSWORD" ]
  then
    get_input "root"
    ROOT_PASSWORD=$INPUT
  fi

  echo 'Setting root password'
  set_root_password "$ROOT_PASSWORD"

  if [ -z "$USER_PASSWORD" ]
  then
    get_input "$USER_NAME"
    USER_PASSWORD=$INPUT
  fi

  echo 'Creating initial user'
  create_user "$USER_NAME" "$USER_PASSWORD"

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
elif [ "$#" -ne 2 ]
then
  echo "Usage: $0 <cfg_dir> <disk prepare script>"
else
  setup $0 $1 $2
fi
