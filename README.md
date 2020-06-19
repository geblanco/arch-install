# Arch Install from a script

Before installing, get the correct info from your drives with (`sudo fdisk -l`) and correct `/dev/sdX` drives in disk.sh script.

## Software

Fill in all the packages you want to install in `cfgs/software.txt`. To replicate your current system, issue `./get_sofware.sh` on your local system.

## Bootloader

Before installing, a bootloader must be chosen (systemd by default, recommended). If using other bootloader different from systemd, enable it in `set_bootloader` function, inside install script.
If using systemd, fill in the root partition inside `cfgs/arch.conf`.

## Installation

In order to install the system, just run `./install.sh cfgs disks.sh`
