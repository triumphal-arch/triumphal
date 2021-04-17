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
    package_dir=$build_dir/$package_name

    echo "Building " $package_name
    if [ -e $package_dir ]
    then
        pushd $package_dir >> /dev/null
        git pull
    else
        echo asdf
        git clone $git_package_url $package_dir
        echo asdf
        pushd $package_dir >> /dev/null
    fi
    makepkg $package_name
    mv $package_name-* $database_dir
    popd >> /dev/null
}


cleanup () {
    if [ $use_swapfile = true ]
    then
        sudo swapoff $swapfile
        sudo rm $swapfile
    fi
    sudo umount $(/usr/bin/mount | grep $work_dir/ | cut -f3 -d ' ')
    sudo rm -rf $work_dir
}

### Directory paths ###
archiso_example_profile='/usr/share/archiso/configs/releng'
profile_dir=$(pwd)/archiso_profile
build_dir=$(pwd)/build
database_dir=$build_dir/packages
work_dir='/tmp/archiso_workdir'
installer_config=$(pwd)/installer_config
installer_config_target=$build_dir'/airootfs/etc/os-installer'


### Prepare for build ###
#remove previous build
sudo rm -rf $build_dir
cleanup
# flags for file creation
umask 0022


### Setup airootfs ###
mkdir -p $build_dir
cp -a $archiso_example_profile/* $build_dir
# remove unwanted, patch and add files from/to default profile.
for line in $(cat $profile_dir/remove); do rm -rf $build_dir/$line; done
for file in $(ls  $profile_dir/patch);  do cat $profile_dir/patch/$file >> $build_dir/$file; done
for file in $(ls  $profile_dir/add);    do cp -a $profile_dir/add/$file $build_dir/; done
# copy installer config
mkdir -p $installer_config_target
cp -a $installer_config/* $installer_config_target


### Build packages ###
mkdir -p $database_dir
build_package os-installer git@github.com:p3732/os-installer-pkgbuild.git
repo-add $database_dir/triumphal.db.tar.gz $database_dir/*.pkg.tar
sudo sed -i s,@@REPO_PATH@@,$database_dir, $build_dir/pacman.conf


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
# temporarily increase tmpfs size
sudo mount -o remount,size=7G,noatime /tmp

### Build ISO ###
# create temporary folder
mkdir -p $work_dir
# Run ISO creation with caching in memory  (releng as the profile folder)
sudo mkarchiso -v -w $work_dir -o . build
mkarchiso -v -w $work_dir -o . 

### Cleanup ###
cleanup
