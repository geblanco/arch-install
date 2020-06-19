#!/bin/bash

# get all the installed software

soft=$(pacman -Q | awk '{print $1}')
echo "Found $(echo $soft | tr ' ' '\n' | wc -l) packages"
echo $soft | tr ' ' '\n' > cfgs/software.txt
