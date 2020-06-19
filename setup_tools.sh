#!/bin/bash

##### CUDA #####
## cat /usr/local/cuda/version.txt
##  CUDA Version 10.1.243
## nvcc  --version
##  nvcc: NVIDIA (R) Cuda compiler driver
##  Copyright (c) 2005-2019 NVIDIA Corporation
##  Built on Sun_Jul_28_19:07:16_PDT_2019
##  Cuda compilation tools, release 10.1, V10.1.243
## cat /usr/local/cuda/include/cudnn.h | grep CUDNN_MAJOR -A 2
##  CUDNN_MAJOR 7
##  CUDNN_MINOR 6
##  CUDNN_PATCHLEVEL 5
yay -S nvidia nvidia-settings nvidia-utils cuda-10.1 cudnn --noconfirm

##### Anaconda #####
cd ~
mkdir build
anaconda_installer='Anaconda3-2020.02-Linux-x86_64.sh'
[[ -f "$anaconda_installer" ]] && rm "$anaconda_installer"
wget "https://repo.anaconda.com/archive/${anaconda_installer}"
chmod +x "$anaconda_installer"
./$anaconda_installer

##### Docker #####
sudo groupadd docker
sudo usermod -aG docker $USER
newgrp docker 
docker run hello-world
