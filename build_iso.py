# SPDX-License-Identifier: GPL-3.0-or-later

import argparse
from fileinput import filename
import os
from pathlib import Path
import profile
import shutil
import subprocess


packages = [
    ('os-installer', 'https://github.com/triumphal-arch/os-installer-pkgbuild.git'),
    ('vte4-git', 'https://aur.archlinux.org/vte4-git.git'),
    ('gnome-shell-extension-no-overview', 'https://aur.archlinux.org/gnome-shell-extension-no-overview.git'),
]

distro_name = 'triumphal'

pwd = Path(os.getcwd())
path = {
    'archiso_example_profile': Path('/usr/share/archiso/configs/releng'),
    'autostart':               pwd / 'build/profile/airootfs/etc/skel/.config/autostart',
    'build_profile':           pwd / 'build/profile',
    'build':                   pwd / 'build',
    'database':                pwd / 'build/database',
    'installer_config_target': pwd / 'build/profile/airootfs/etc/os-installer',
    'installer_config':        pwd / 'installer_config',
    'source_profile':          pwd / 'archiso_profile',
    'stashed_work':            pwd / 'build/stashed_archiso_workdir',
    'swapfile':                Path('/swapfile_iso_build'),
    'work':                    Path('/tmp/archiso_workdir'),
}

verbose = False


### args ###


def handle_args():
    parser = argparse.ArgumentParser(
        description='Build a Triumphal .iso image. Requires about 6GB of space.')
    parser.add_argument('-b', '--big-tmpfs', action='store_true',
                        help='Remounts /tmp with increased tmpfs size')
    parser.add_argument('-v', '--verbose', action='store_true',
                        help='More verbose output')
    parser.add_argument('-p', '--skip-profile', action='store_true',
                        help='Skips rebuilding of the archiso profile (airootfs)')
    parser.add_argument('-s', '--use-swapfile', action='store_true',
                        help='Create and use a swapfile for build (requires 7 GB of free space)')
    parser.add_argument('--cleanup-after', action='store_true',
                        help='Cleanup working directory (in /tmp). Only useful with --no-stash-workdir')
    parser.add_argument('--from-scratch', action='store_true',
                        help='Throw everything away and start over')
    parser.add_argument('--no-stash-workdir', action='store_true',
                        help="Don't stash working directory to build folder when done")
    args = parser.parse_args()

    global verbose
    verbose = args.verbose

    return args


### helpers ###


def copy(*args, **kwargs):
    return shutil.copy2(*args, **kwargs)


def debug(*args):
    if verbose:
        print('    ', *args)


def exec(args, **kwargs):
    out = subprocess.run(args.split(' '), capture_output=True, **kwargs)
    if out.stdout:
        return out.stdout.decode().strip()


def indent(*args):
    print('  ')


def launch_process(args, cwd=None, **kwargs):
    process = subprocess.Popen(args.split(' '),
                               cwd=str(cwd) if cwd else None, **kwargs)
    #print('process', process)
    process.wait()


def error(*args):
    print('ERROR: ', end='')
    print(*args)


def find(path, name):
    return exec(f'find . -name {name}', cwd=path)


def mkdir(name):
    os.makedirs(path[name], exist_ok=True)


def remove(path):
    return exec(f'rm -rf {str(path)}')


def strpath(name):
    return str(path[name])


def sudo(args):
    return exec('sudo ' + args)


### functionality ###


def build_database():
    print('Building database')
    database_dir = path['database']
    database = database_dir / (distro_name + '.db.tar.gz')

    debug('Removing old database')
    remove(database)
    remove(database_dir / (distro_name + '.db'))
    remove(database_dir / (distro_name + '.files'))
    remove(database_dir / (distro_name + '.files.tar.gz'))

    packages = find(database_dir, '*.pkg.tar')
    for package in packages.split():
        debug(f'Adding {package} to database')
        exec(f"repo-add {database} {str(database_dir/package)}")


def build_iso():
    '''
    Run ISO creation with caching in memory  (releng as the profile folder)
    '''
    print('Building .iso image')
    mkdir('work')

    sudo(f"rm -rf {strpath('work')}")
    launch_process(
        f"sudo mkarchiso -v -w {strpath('work')} -o . {strpath('build_profile')}")
    sudo(f"rm -rf {strpath('work')}")


def build_package(name, url):
    database_dir = path['database']
    package_dir = database_dir / name
    print(f'Building {name}')

    old_tarball = find(database_dir, f'{name}*.pkg.tar')
    if package_dir.exists():
        # check for new commits
        previous_commit = exec(f'git rev-parse HEAD', cwd=package_dir)
        exec('git pull', cwd=package_dir)
        current_commit = exec('git rev-parse HEAD', cwd=package_dir)
        if previous_commit == current_commit and old_tarball:
            debug('Already built, skipping')
            return False
    else:
        exec(f'git clone {url} {str(package_dir)}', cwd=database_dir)

    launch_process(f"bash -c makepkg --syncdeps",
                   cwd=package_dir,
                   env={"PKGEXT": ".pkg.tar", 'PATH': '/usr/bin'})

    if old_tarball:
        debug('Removing old tarball')
        remove(old_tarball)

    new_tarball = find(package_dir, f'{name}-*.tar')
    if not new_tarball:
        error(f"Couldn't build tarball for {name}")
        return
    shutil.move(package_dir/new_tarball, path["database"])
    return True


def build_packages():
    mkdir('database')

    packages_changed = False
    for name, package in packages:
        ret = build_package(name, package)
        packages_changed |= ret

    database = Path(distro_name + 'db.tar.gz')
    if packages_changed or not database.exists():
        build_database()


def cleanup_mounts():
    mounts = exec(f"/usr/bin/mount | grep {strpath('work')} | cut -f3 -d ' '")
    if mounts:
        # TODO test
        print('mounts:', mounts)
        for mount in mounts.split(' '):
            sudo(f'umount -q {mount}')
            sudo(f'umount -q {mount}')  # twice because of dependencies


def cleanup_swapfile():
    # TODO test
    if not path['swapfile'].exists():
        return
    swapfile = str(path['swapfile'])
    sudo(f'swapoff {swapfile}')
    sudo(f'rm {swapfile}')


def cleanup_work_folder():
    # TODO test
    remove(path['work'])


def restore_workdir():
    if path['stashed_work'].exists():
        print('Restoring stashed archiso workdir')
        sudo(f"mv {str(path['stashed_work'])} {str(path['work'])}")


def stash_workdir():
    print('Stashing archiso workdir')
    a = sudo(f"mv {str(path['work'])} {str(path['stashed_work'])}")
    print(a)


def setup_airootfs():
    print('Creating archiso profile')

    build_profile = path['build_profile']
    src_profile = path['source_profile']

    # remove old profile
    sudo(f"rm -rf {str(build_profile)}")

    mkdir('build_profile')
    mkdir('installer_config_target')

    # base on default archiso profile
    example_path = path['archiso_example_profile']
    for source_file in os.listdir(example_path):
        exec(f"cp -a {str(example_path/source_file)} {str(build_profile)}")

    # remove unwanted files
    with open(src_profile/'remove') as file:
        for file_name in file.read().splitlines():
            debug('Removing', build_profile/file_name)
            remove(build_profile/file_name)

    # add additional files
    add_dir = src_profile/'add'
    for file in os.listdir(add_dir):
        source_path = add_dir/file
        debug('Adding', source_path)
        exec(f"cp -a {str(source_path)} {str(build_profile)}")

    # patch by stripping from files
    strip_path = src_profile/'patch/strip'
    for file_name in os.listdir(strip_path):
        dest_path = build_profile/file_name
        if not dest_path.exists():
            error(f'Tried patching a nonexistant file! ({str(dest_path)})')
            continue
        with open(strip_path/file_name) as src_file:
            debug(f'Patching {src_file.name} out of {dest_path}')
            for line in src_file.read().splitlines():
                exec(f'sed -i /^{line.strip()}/d {file_name}',
                     cwd=build_profile)

    # patch by appending to files
    append_path = src_profile/'patch/append'
    for file_name in os.listdir(append_path):
        dest_path = build_profile/file_name
        if not dest_path.exists():
            error(f'Tried patching a nonexistant file! ({str(dest_path)})')
            continue
        with open(append_path/file_name) as src_file:
            with open(dest_path, 'a') as dest_file:
                debug(f'Patching {src_file.name} in to {dest_path}')
                for line in src_file:
                    dest_file.write(line)

    # set correct database path
    sudo(f"sed -i s,@@REPO_PATH@@,{strpath('database')}, \
         {str(path['build_profile']/'pacman.conf')}")


def setup_autostart():
    '''
    Find os-installer desktop file and put it in autostart folder.
    '''
    print('Adding os-installer to autostart')
    mkdir('autostart')
    search_dir = path['database']/'os-installer/pkg'
    desktop_file = find(search_dir, "*.desktop")
    copy(search_dir/desktop_file, path['autostart'])


def setup_big_tmpfs():
    # increase tmpfs size
    sudo('mount -o remount,size=7G,noatime /tmp')


def setup_swapfile():
    # TODO this is not tested
    if path['swapfile'].exists():
        print('swapfile already exists')
        return
    swapfile = str(path['swapfile'])
    sudo(f'touch {swapfile}')
    sudo(f'chmod 600 {swapfile}')
    sudo(f'chattr +C {swapfile}')
    sudo(f'fallocate -l 7G {swapfile}')
    sudo(f'mkswap {swapfile}')
    sudo(f'swapon {swapfile}')


def wipe_build_folder():
    print('Cleaning build directory…')
    remove(path['build'])


### main ###


def main():
    args = handle_args()
    os.umask(18)  # flags for file creation, 18 is octal 22

    if args.from_scratch:
        wipe_build_folder()
        cleanup_work_folder()
    if not path['build_profile'].exists() or not args.skip_profile:
        setup_airootfs()

    build_packages()
    setup_autostart()

    if args.use_swapfile:
        setup_swapfile()
    if args.big_tmpfs:
        setup_big_tmpfs()

    #if not args.no_stash_workdir:
    #    restore_workdir()
    build_iso()
    cleanup_mounts()  # only needed if build fails
    #if not args.no_stash_workdir:
    #    stash_workdir()

    if args.use_swapfile:
        cleanup_swapfile()
    if args.cleanup_after and args.no_stash_workdir:
        cleanup_work_folder()


if __name__ == "__main__":
    main()
