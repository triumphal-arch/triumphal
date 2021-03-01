#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later

from distutils import dir_util
from pathlib import Path
from shutil import copy

archiso_example_profile = Path('/usr/share/archiso/configs/releng/')
archiso_profile = Path.cwd() / 'archiso_profile'
builddir = Path.cwd() / 'build'


def check_things_are_ok():
    if (not archiso_example_profile.is_dir()):
        print("Can't find archiso default config.")
        exit()
    if (not archiso_profile.is_dir()):
        print("Can't find archiso config.")
        exit()


def prepare_build_directory():
    builddir.mkdir(exist_ok=True)
    dir_util.copy_tree(str(archiso_example_profile), str(builddir), preserve_symlinks=True)
    strip_unwanted_from_builddir()
    patch_files()
    copy_directories()
    copy_files()


def strip_unwanted_from_builddir():
    removed_directories_path = archiso_profile / 'removed_directories'
    with open(removed_directories_path) as removed_directories:
        for removed_directory in removed_directories.read().splitlines():
            dir_util.remove_tree(str(builddir / removed_directory))

    removed_files_path = archiso_profile / 'removed_files'
    with open(removed_files_path) as removed_files:
        for removed_file in removed_files.read().splitlines():
            remove_path = builddir / removed_file
            remove_path.unlink()


def patch_files():
    files_to_patch_path = archiso_profile / 'files_to_patch'
    with open(files_to_patch_path) as files_to_patch:
        for file_name in files_to_patch.read().splitlines():
            file_path = builddir / file_name
            patch_file_path = archiso_profile / ('append_'+file_name)
            with open(file_path, "a") as file:
                with open(patch_file_path, "r") as patch_file:
                    for line in patch_file:
                        file.write(line)


def copy_directories():
    copied_directories_path = archiso_profile / 'copied_directories'
    with open(copied_directories_path) as copied_directories:
        for copied_directory in copied_directories.read().splitlines():
            src = str(archiso_profile / copied_directory)
            dst = str(builddir / copied_directory)
            dir_util.copy_tree(src, dst, preserve_symlinks=True)

def copy_files():
    copy(archiso_profile / 'profiledef.sh', builddir / 'profiledef.sh')


check_things_are_ok()
prepare_build_directory()
