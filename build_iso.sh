#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later

# directory paths
archiso_example_profile='/usr/share/archiso/configs/releng/'
profile_dir=$(pwd)/archiso_profile
build_dir=$(pwd)/build
package_dir=$build_dir/packages

# remove previous build
sudo rm -rf $build_dir
sudo rm -rf triumphal-*
#sudo rm -rf /tmp/archiso_workdir

#for file creation flags
umask 0022

# Create directories
mkdir -p $package_dir

# Setup airottfs
cp -a $archiso_example_profile $build_dir
# remove unwanted, patch and add files from/to default profile.
for line in $(cat $profile_dir/remove); do rm -rf $build_dir/$line; done
for file in $(ls  $profile_dir/patch);  do cat $profile_dir/patch/$file >> $build_dir/$file; done
for file in $(ls  $profile_dir/add);    do cp -a $profile_dir/add/$file $build_dir/; done

### build packages ###

package_name=os-installer
pushd $build_dir/$package_name >> /dev/null
makepkg $package_name
mv $package_name-* $package_dir
popd >> /dev/null

repo-add $build_dir/triumphal.db.tar.gz $package_dir/*
sudo sed -i s,@@REPO_PATH@@,$build_dir, $build_dir/pacman.conf

### prepare build system ###
# create temporary folder
mkdir -p /tmp/archiso_workdir
# temporarily increase tmpfs size
sudo mount -o remount,size=7G,noatime /tmp

### build ###
# Run ISO creation with caching in memory  (releng as the profile folder)
sudo mkarchiso -v -w /tmp/archiso_workdir -o . build
