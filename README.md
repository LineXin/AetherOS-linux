# AetherOS Linux

A Debian 13 (Trixie)-based Linux distribution project featuring XFCE and KDE Plasma desktop editions, Firefox, and the AetherHub settings center.

> **Status:** Early development. The first CI build is a Debian Installer-based prototype with AetherOS branding and a preseed configuration. Desktop images and fully integrated AetherHub are not yet implemented.

## Planned editions
- **AetherOS XFCE** — lightweight desktop
- **AetherOS KDE** — KDE Plasma desktop

## Build
GitHub Actions currently produces a prototype installer ISO by downloading the official Debian 13 amd64 netinst image and adding project branding and installer configuration.

Run **Actions → Build AetherOS Installer → Run workflow**. The ISO is uploaded as a workflow artifact.

## Project
- Base: Debian 13 Trixie
- Architecture: amd64
- Installer: Debian Installer (prototype)
- Browser: Firefox (planned in the installed system)
- Settings center: AetherHub (planned)

This project is not affiliated with Debian.
