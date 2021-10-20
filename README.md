# Arch Install from a script [GPU SERVER VERSION]

Before installing
- get the correct info from your drives with (`sudo fdisk -l`) and correct `/dev/sdX` drives in disk.sh script.
- change the necessary variables in install.sh script (HOSTNAME, HOSTDOMAIN, USER_NAME, USER_PASSWORD)

## Software

By the default, the LTS version of the kernel will be installed, if you want to install
the latest version, just change it in the `install_base` function inside the installer script.

Fill in all the packages you want to install in `cfgs/software.txt`. To replicate your current system, issue `./get_sofware.sh` on your local system.

## Bootloader

Before installing, a bootloader must be chosen (systemd by default, recommended). If using other bootloader different from systemd, enable it in `set_bootloader` function, inside install script.
If using systemd, fill in the root partition inside `cfgs/arch.conf`.

## Installation

In order to install the system, just run `./install.sh cfgs disks.sh`

## CUDA
When installing CUDA, there are two separate parts:
- The API
- The drivers

Once installed,
`nvcc` shows the drivers results, `nvidia-smi` shows the API results

The kernel module and CUDA "driver" library are shipped in nvidia and opencl-nvidia.
The "runtime" library and the rest of the CUDA toolkit are available in cuda.
These are the minimum packages that should be installed at the end of the setup:
- nvidia-utils (provided by nvidia-utils)
- opencl-nvidia (provided by nvidia-utils)
- nvidia-dkms (provided by nvidia-utils)
- cuda

At the time of writing (Oct-2021), the latest driver version was 470, which
has many problems (being the latest available version, for starters), so, to
install version 450 of the drivers, we will install from a local PKGBUILD found
in pkgs/nvidia-utils

To setup everything, launch `./setup_cuda.sh`

## Notes
Updating CUDA packages may render the GPUs useless due to version mismatches.
To avoid this, add: `IgnorePkg = python cuda nvidia-utils opencl-nvidia
nvidia-dkms` to your pacman conf file (`/etc/pacman.conf`)
