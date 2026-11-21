# AetherOS Linux

A Debian-based Linux distribution project with a custom identity, XFCE and KDE Plasma desktop sessions, Fastfetch branding, original wallpapers, and the AetherHub settings center.

> **Status:** Active development. The repository contains live-build branding assets and a GTK4 AetherHub prototype. Always test generated ISOs in a virtual machine before installing on physical hardware.

## Desktop environments

The current package list includes both XFCE and KDE Plasma sessions. The login manager lets users select the desktop session. The current wallpaper helper supports both desktops.

## AetherOS identity

- Name: AetherOS
- ID: `aetheros`
- ID_LIKE: `debian`
- Tagline: **PURE. FAST. REFINED.**
- Default hostname: `aetheros`

## Branding assets

- `config/includes.chroot/usr/share/aetheros/branding/aetheros.txt` — Fastfetch ASCII logo
- `aetheros-logo.svg` — graphical mark
- `aetheros-wallpaper-mountain.svg` — mountain dusk wallpaper
- `aetheros-wallpaper-abstract.svg` — graphite/orange abstract wallpaper

## AetherHub

A native GTK4 application with Overview, Performance, Services, Appearance, and About sections. It uses a restricted helper for CPU governor, swappiness, ZRAM, and selected system services. Hardware and service availability varies.

## Build

Run `bash scripts/prepare-live-build.sh` before your live-build command. The script sets executable permissions on chroot hooks and helper scripts.

## Project

- Base: Debian
- Desktop: XFCE + KDE Plasma
- Architecture: amd64 (current CI target)
- Settings center: AetherHub

AetherOS is an independent project and is not affiliated with Debian.
