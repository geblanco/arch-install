#!/bin/bash

## Setup disks
##  Current disks:
##    /dev/sda: 1TB HHD
##      | gpt partition table
##      |-- 500GB /home
##    /dev/sdb: 256 GB SSD
##      | gpt partition table
##      |-- 512MB /boot (boot, esp)
##      |-- 40GB /
##      |-- 32GB SWAP (swap)

partition_drives() {
  local dev="$1"; shift

  # 512 MB /boot partition (boot, esp flags)
  # 40 GB /root partition
  # 32 GB [SWAP] partition (swap flag)
  parted -s "$dev" \
      mklabel gpt -- \
      mkpart "/boot" fat32 1 512M \
      mkpart "/" ext4 512M 41G  \
      mkpart "swap" linux-swap 41G 53G \
      mkpart "/home" ext4 53G 1000G \
      set 1 bios_grub on \
      set 1 boot on
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

  mkfs.vfat -F32 "$boot_dev"
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

work() {

  local DRIVE='/dev/sda'

  local boot_dev="$DRIVE"1
  local root_dev="$DRIVE"2
  local swap_dev="$DRIVE"3
  local home_dev="$DRIVE"4

  echo 'Partition drive'
  partition_drives "$DRIVE"

  echo 'Formatting filesystems'
  format_filesystems "$boot_dev" "$root_dev" "$swap_dev" "$home_dev"

  echo 'Mounting filesystems'
  mount_filesystems "$boot_dev" "$root_dev" "$swap_dev" "$home_dev"
}

echo "========= Disks util ========="
work
exitcode=$?

if [[ $exitcode -eq 0 ]]; then
  echo "=============================="
else
  exit $exitcode
fi
