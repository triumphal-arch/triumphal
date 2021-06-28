# TODO

## Installed System
* Firefox
    * Configure firefox to install gnome shell extensions addon and ublock origin
    * disable pocket and ad stuff

* build and install yay into iso + system

* Post Install configuration list
    * copy some settings of current user?
        * do not copy .mozilla cause of cache?
    * copy configured wifis
        * /etc/NetworkManager/system-connections/
    * enable all needed system daemons (homed?)
    * sanitize journald max size
    * configure paccache to only keep two versions
    * post kernel-upgrade module sanity
    * kill process before complete system lock due to too little available RAM
       * oomd aur package
      * also swapfile? z-ram?
    * autoupdate if possible, preventing shutdown
    * enable multilib in /etc/pacman.conf
    * move pacman lock to /tmp

* use meson instead of build_iso.sh