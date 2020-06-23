#!/bin/bash

## Setup disks
##  Current disks:
##    /dev/sda: 512 GB SSD
##      | gpt partition table
##      |-- 512 MB /boot (boot, esp)
##      |-- 128 GB /
##      |-- 128 GB SWAP (swap)
##      |-- ~256 GB /home
##    /dev/sdb: 3 TB SATA
##      | gpt partition table
##      |-- 3 TB /data

partition_drives() {
  local dev="$1"; shift

  # 512 MB /boot partition (boot, esp flags)
  # 128 GB /root partition
  # 128 GB [SWAP] partition (swap flag)
  parted -s "$dev" \
      mklabel gpt -- \
      mkpart "/boot" fat32 1 512M \
      mkpart "/" ext4 512M 128G  \
      mkpart "swap" linux-swap 128G 256G \
      mkpart "/home" ext4 256G 100% \
      set 1 bios_grub on \
      set 1 boot on
}

partition_data_drive(){
  local dev=$1; shift
  local name=${1:-"/data"}
  parted -s "$dev" mkpart "$name" ext4 100%
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

format_data_filesystem(){
  local dev=$1; shift
  if [[ "$#" -gt 0 ]]; then
    local name=$1
    mkfs.ext4 -L "$name" "$dev"
  else
    mkfs.ext4 "$dev"
  fi
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

mount_data_filesystem(){
  local dev=$1; shift
  local name=${1:-"data"}
  mkdir "/mnt/${name}"
  mount "$dev" "/mnt/${name}"
}

############# UNUSED ################
unmount_filesystems() {
  local swap_dev="$1"; shift

  umount /mnt/home
  umount /mnt/boot
  umount /mnt
  swapoff "$swap_dev"
}

erase_drives() {
  local erase="$1"; shift
  local part="$1"; shift
  parted -s $erase rm $part
}
#####################################

work() {

  local DRIVE='/dev/nvme0n1'
  local DATA_DRIVE='/dev/sda'
  local DATA_DRIVE_NAME='data'

  local boot_dev="${DRIVE}"1
  local root_dev="${DRIVE}"2
  local swap_dev="${DRIVE}"3
  local home_dev="${DRIVE}"4

  echo 'Partition drive'
  partition_drives "$DRIVE"
  partition_data_drive "$DATA_DRIVE" "/${DATA_DRIVE_NAME}"

  echo 'Formatting filesystems'
  format_filesystems "$boot_dev" "$root_dev" "$swap_dev" "$home_dev"
  format_data_filesystem "$DATA_DRIVE" "$DATA_DRIVE_NAME"

  echo 'Mounting filesystems'
  mount_filesystems "$boot_dev" "$root_dev" "$swap_dev" "$home_dev"
  mount_data_filesystem "$DATA_DRIVE" "$DATA_DRIVE_NAME"
}

echo "========= Disks util ========="
work
exitcode=$?

if [[ $exitcode -eq 0 ]]; then
  echo "=============================="
else
  exit $exitcode
fi
