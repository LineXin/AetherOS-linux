# AetherOS branding and AetherHub integration

## live-build paths
- `config/includes.chroot/etc/aetheros/os-release`: source identity file
- `config/includes.chroot/etc/issue`, `issue.net`, `lsb-release`, `hostname`, `hosts`: identity defaults
- `config/includes.chroot/etc/default/grub.d/99-aetheros.cfg`: GRUB distributor
- `config/includes.chroot/usr/share/aetheros/branding/`: ASCII logo and SVG wallpaper
- `config/includes.chroot/etc/skel/.config/fastfetch/`: default Fastfetch profile
- `config/hooks/live/0100-aetheros-branding.hook.chroot`: protected branding
- `config/hooks/live/0200-aetheros-defaults.hook.chroot`: sysctl and shell defaults
- `config/includes.chroot/usr/local/sbin/aetheros-tune`: validated privileged helper
- `config/includes.chroot/usr/lib/aetherhub/aetherhub.py`: GTK4 settings app

## Build integration
Run `bash scripts/prepare-live-build.sh` before `lb build`. Ensure `config/package-lists/aetheros.list.chroot` is included in the live-build configuration.

## AetherHub
The GTK4 prototype offers CPU governor, vm.swappiness, ZRAM service, Bluetooth/CUPS/thermald controls, and XFCE wallpaper action. The helper validates each operation; it does not accept arbitrary shell commands. Service availability depends on installed packages and hardware. Governor choices depend on the CPU driver. ZRAM uses `zramswap.service`. CPU governor changes are runtime-only.

## Branding
The SVG asset is installed under `/usr/share/aetheros/branding/`, and copied to `/usr/share/backgrounds/` and `/usr/share/pixmaps/`. The GRUB distributor label is configured; a graphical GRUB theme still needs its own theme assets and bootloader configuration.

The hook diverts `/usr/lib/os-release`, `/etc/issue`, `/etc/issue.net`, and `/etc/lsb-release`. Hostname and hosts are written directly. This does not prevent an administrator or another package from intentionally replacing them.
