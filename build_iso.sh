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
    package_dir=$database_dir/$package_name

    echo "Building " $package_name
    if [ -e $package_dir ]
    then
        pushd $package_dir >> /dev/null
        git pull
    else
        git clone $git_package_url $package_dir
        pushd $package_dir >> /dev/null
    fi
    makepkg $package_name
    mv $package_name-* $tarball_dir
    popd >> /dev/null
}

cleanup () {
    mounts=$(/usr/bin/mount | grep $work_dir/ | cut -f3 -d ' ')
    if [ ! $mounts == '' ]
    then
        echo sudo umount -q $mounts
    fi
    sudo rm -rf $work_dir
}

cleanup_swapfile () {
    if [[ $use_swapfile = true && -e $swapfile ]]
    then
        sudo swapoff $swapfile
        sudo rm $swapfile
    fi
}


### Directory paths ###
archiso_example_profile='/usr/share/archiso/configs/releng'
profile_dir=$(pwd)/archiso_profile
build_dir=$(pwd)/build
build_profile_dir=$build_dir/profile
database_dir=$build_dir/packages
tarball_dir=$database_dir/tarballs
work_dir='/tmp/archiso_workdir'
installer_config=$(pwd)/installer_config
installer_config_target=$build_profile_dir'/airootfs/etc/os-installer'
# file paths
swapfile=/swapfile_iso_build

### Prepare for build ###
# remove previous build stuf^
sudo rm -rf $build_profile_dir
cleanup
# flags for file creation
umask 0022


### Setup airootfs ###
mkdir -p $build_dir
mkdir -p $build_profile_dir
cp -a $archiso_example_profile/* $build_profile_dir
# remove unwanted, patch and add files from/to default profile.
for line in $(cat $profile_dir/remove); do rm -rf $build_profile_dir/$line; done
for file in $(ls  $profile_dir/patch);  do cat $profile_dir/patch/$file >> $build_profile_dir/$file; done
for file in $(ls  $profile_dir/add);    do cp -a $profile_dir/add/$file $build_profile_dir/; done
# copy installer config
mkdir -p $installer_config_target
cp -a $installer_config/* $installer_config_target


### Build packages ###
mkdir -p $database_dir
mkdir -p $tarball_dir
build_package os-installer git@github.com:p3732/os-installer-pkgbuild.git
repo-add $database_dir/triumphal.db.tar.gz $tarball_dir/*.pkg.tar
sudo sed -i s,@@REPO_PATH@@,$database_dir, $build_profile_dir/pacman.conf


### Prepare build system ###
# create backup swapfile
if [[ $use_swapfile = true &&  -n $swapfile ]]
then
    sudo touch $swapfile
    sudo chmod 600 $swapfile
    sudo chattr +C $swapfile
    sudo fallocate -l 7G  $swapfile
    sudo mkswap $swapfile
    sudo swapon $swapfile
fi
# temporarily increase tmpfs size
sudo mount -o remount,size=7G,noatime /tmp

### Build ISO ###
# create temporary folder
mkdir -p $work_dir
# Run ISO creation with caching in memory  (releng as the profile folder)
sudo mkarchiso -v -w $work_dir -o . $build_profile_dir
mkarchiso -v -w $work_dir -o . 

### Cleanup ###
cleanup
cleanup_swapfile
