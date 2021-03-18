#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later

# Remove previous build
sudo rm -rf build
sudo rm -rf triumphal-*
sudo rm -rf /tmp/archiso_workdir

#for file creation flags
umask 0022

### prepare archiso ###
sudo ./setup_archiso_profile.py

###
# Extra packages
###
gsudo mkdir -p build/packages/
pushd build/packages
sudo chown -R $(whoami) .
REPO_PATH=$(pwd)

PACKAGE_NAME="os-installer"
# TODO download from repos with PKGBUILD eventually (for now it is in this repo)

pushd $PACKAGE_NAME
makepkg $PACKAGE_NAME
mv *.pkg.tar $REPO_PATH
popd

#PACKAGE_NAME="uvesafb-dkms"
#wget https://aur.archlinux.org/cgit/aur.git/snapshot/uvesafb-dkms.tar.gz
#tar -xf $PACKAGE_NAME*
#pushd $PACKAGE_NAME
#makepkg $PACKAGE_NAME
#mv *.pkg.tar $REPO_PATH
#popd

repo-add triumphal.db.tar.gz *

popd
sudo sed -i s,@@REPO_PATH@@,$REPO_PATH, build/pacman.conf

# enable uvesafb-dkms
#sudo sed -i s,HOOKS="(base udev","HOOKS=(base udev v86d", build/airootfs/etc/mkinitcpio.conf
# append to /etc/default/grup GRUB_DISABLE_OS_PROBER=false

exit

### prepare build system ###
# create temporary folder
mkdir -p /tmp/archiso_workdir
# temporarily increase tmpfs size
sudo mount -o remount,size=7G,noatime /tmp

### build ###
# Run ISO creation with caching in memory  (releng as the profile folder)
sudo mkarchiso -v -w /tmp/archiso_workdir -o . build
