# Triumphal Arch Linux
Main repository for Triumphal Arch Linux.

## Create ISO
This builds an iso image in RAM, which requires about 7GB of available main/swap memory.
```script
python ./build_iso.py
```

If less memory is available, the parameter `--use-swapfile` can be used (requires 7GB of disk space).

## Dependencies
```script
sudo pacman -S archiso
```
