# AetherOS Linux

A Debian-based Linux distribution project with a custom identity, XFCE and KDE Plasma desktop editions, Fastfetch branding, original wallpapers, and the AetherHub settings center.

> **Status:** Development. The current CI pipeline repacks official Debian Live images with AetherOS project assets. Full integration of chroot hooks, package lists, wallpapers, and AetherHub into the live root filesystem is still in progress.

## Desktop editions

- **AetherOS XFCE** — Debian 13.8.0 XFCE Live base.
- **AetherOS KDE** — Debian 13.8.0 KDE Live base.

## Build and publish

The GitHub Actions workflow builds both Live ISO editions and publishes them to **GitHub Releases**, not expiring workflow artifacts.

1. Open Actions → Build and publish AetherOS Live ISO.
2. Select Run workflow and enter a release tag, for example v0.1.0.
3. Open Releases after the workflow succeeds.
4. Download all numbered parts for the chosen desktop edition and SHA256SUMS.
5. Reconstruct the ISO:

    cat AetherOS-13.8.0-amd64-XFCE.iso.part-* > AetherOS-13.8.0-amd64-XFCE.iso
    sha256sum --ignore-missing -c SHA256SUMS

For KDE, replace XFCE with KDE in the filenames. Or use the helper: bash scripts/join-release-iso.sh AetherOS-13.8.0-amd64-XFCE.iso.part- AetherOS-13.8.0-amd64-XFCE.iso

You can also push a version tag beginning with v to trigger publishing.

## Current build limitation

The current script downloads official Debian Live XFCE and KDE images, verifies upstream SHA256 checksums, and adds AetherOS project files under /AETHEROS/ inside each ISO. It does not yet replace Debian's live root filesystem with the custom files under config/includes.chroot/. The project is working toward a fully integrated live-build image.

AetherOS is an independent project and is not affiliated with Debian.
