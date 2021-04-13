#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later

### Parse arguments ###
if [[ ! -z $1 && $1 == "--use-swapfile" ]]
then
    use_swapfile=true
else
    use_swapfile=false
fi


build_package () {
    package_name=$1
    git_package_url=$2

    echo "Building " $package_name
    git clone $git_package_url $build_dir/$package_name
    pushd $build_dir/$package_name >> /dev/null
    makepkg $package_name
    mv $package_name-* $package_dir
    popd >> /dev/null
}


### Directory paths ###
archiso_example_profile='/usr/share/archiso/configs/releng'
profile_dir=$(pwd)/archiso_profile
build_dir=$(pwd)/build
package_dir=$build_dir/packages
work_dir=$build_dir/work_dir


### Prepare for build ###
#remove previous build
sudo rm -rf $build_dir
sudo rm -rf triumphal-*
sudo rm -rf /tmp/archiso_workdir
# flags for file creation
umask 0022


### Setup airottfs ###
mkdir -p $build_dir
cp -a $archiso_example_profile/* $build_dir
# remove unwanted, patch and add files from/to default profile.
for line in $(cat $profile_dir/remove); do rm -rf $build_dir/$line; done
for file in $(ls  $profile_dir/patch);  do cat $profile_dir/patch/$file >> $build_dir/$file; done
for file in $(ls  $profile_dir/add);    do cp -a $profile_dir/add/$file $build_dir/; done


### Build packages ###
mkdir -p $package_dir
build_package os-installer git@github.com:p3732/os-installer-pkgbuild.git
repo-add $package_dir/triumphal.db.tar.gz $package_dir/*
sudo sed -i s,@@REPO_PATH@@,$package_dir, $build_dir/pacman.conf


### Prepare build system ###
# create backup swapfile
if [ $use_swapfile = true ]
then
    swapfile=/swapfile_iso_build
    if [ -n $swapfile ]
    then
        sudo touch $swapfile
        sudo chmod 600 $swapfile
        sudo chattr +C $swapfile
        sudo fallocate -l 7G  $swapfile
        sudo mkswap $swapfile
        sudo swapon $swapfile
    fi
fi
# create temporary folder
mkdir -p /tmp/archiso_workdir
# temporarily increase tmpfs size
sudo mount -o remount,size=7G,noatime /tmp

### Build ISO ###
mkdir -p $work_dir
# Run ISO creation with caching in memory  (releng as the profile folder)
sudo mkarchiso -v -w /tmp/archiso_workdir -o . build
mkarchiso -v -w $work_dir -o . 

if [ $use_swapfile = true ]
then
    sudo swapoff $swapfile
    sudo rm $swapfile
fi
