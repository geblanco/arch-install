#!/bin/bash

set -e
cd pkgs >/dev/null
# nvidia utils
cd nvidia-utils
sudo makepkg -fsi
cd -
git clone https://aur.archlinux.org/cuda-11.0.git
cd cuda-11
sudo makepkg -fsi
cd ../../ >/dev/null
