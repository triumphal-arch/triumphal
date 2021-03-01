#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later

# remove previous build
sudo rm -rf build
sudo rm -rf triumphal-*
sudo rm -rf /tmp/archiso_workdir

#for file creation flags
umask 0022

### prepare archiso ###
sudo ./setup_archiso_profile.py

# build installer
pushd build/os-installer
sudo chown -R $(whoami) .
makepkg os-installer
repo-add os-installer.db.tar.gz os-installer-*
REPO_PATH=$(pwd)
popd
sudo sed -i s,@@REPO_PATH@@,$REPO_PATH, build/pacman.conf

### prepare build system ###
# create temporary folder
mkdir -p /tmp/archiso_workdir
# temporarily increase tmpfs size
sudo mount -o remount,size=7G,noatime /tmp

### build ###
# Run ISO creation with caching in memory  (releng as the profile folder)
sudo mkarchiso -v -w /tmp/archiso_workdir -o . build
