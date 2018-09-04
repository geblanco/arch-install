#!/bin/bash

## Setup disks
##  Current disks:
##    /dev/sda: 1TB HHD
##      | gpt partition table
##      |-- 512MB /boot (boot, esp)
##      |-- 8GB /SWAP
##      |-- 492GB /

partition_drives() {
  local dev="$1"; shift

  parted -s "$dev" \
      mklabel gpt \
      mkpart "/boot" fat16 1 512M \
      mkpart "/" ext4 512M 920G  \
      set 1 boot on \
      set 1 esp on
}

erase_drives() {
  local erase="$1"; shift
  local part="$1"; shift
  parted -s $erase rm $part
}

format_filesystems() {
  local boot_dev="$1"; shift
  local root_dev="$1"; shift

  mkfs.fat -F 16 "$boot_dev"
  mkfs.ext4 -L root "$root_dev"
}

mount_filesystems() {
  local boot_dev="$1"; shift
  local root_dev="$1"; shift

  mount "$root_dev" /mnt
  mkdir /mnt/boot
  mount "$boot_dev" /mnt/boot
}

unmount_filesystems() {
  local swap_dev="$1"; shift

  umount /mnt/boot
  umount /mnt
}

work() {
  local DRIVE='/dev/sda'

  local boot_dev="$DRIVE"1
  local root_dev="$DRIVE"2

  echo 'Partitioning disks'
  partition_drives $DRIVE

  echo 'Formatting filesystems'
  format_filesystems "$boot_dev" "$root_dev"

  echo 'Mounting filesystems'
  mount_filesystems "$boot_dev" "$root_dev"
}

echo "========= Disks util ========="
work
exitcode=$?

if [[ $exitcode -eq 0 ]]; then
  echo "=============================="
else
  exit $exitcode
fi
