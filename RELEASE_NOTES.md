# AetherOS Live ISO — Development Release

## Downloads

This release contains two amd64 editions based on official Debian 13.8.0 Live images:

- **XFCE edition** — Debian Live XFCE base.
- **KDE edition** — Debian Live KDE Plasma base.

Each ISO is split into numbered parts because GitHub limits an individual Release asset to less than 2 GiB. Download every part for the edition you want, then reconstruct the ISO.

## Reconstruct an ISO

Keep all parts for one edition in the same directory and run:

    cat AetherOS-13.8.0-amd64-XFCE.iso.part-* > AetherOS-13.8.0-amd64-XFCE.iso
    sha256sum --ignore-missing -c SHA256SUMS

For KDE, replace XFCE with KDE in both filenames. SHA256SUMS contains hashes of the complete reconstructed ISO files.

## What changed

- Replaced the Debian Installer netinst source with Debian Live images.
- Added separate XFCE and KDE edition outputs.
- Added verification of downloaded Debian Live source images using Debian's published SHA256SUMS.
- Added AetherOS README, ASCII logo, SVG logo, and both wallpaper assets inside the ISO under /AETHEROS/.
- Changed publishing from expiring Actions artifacts to GitHub Releases.
- Added automatic splitting into 1,900 MiB parts to satisfy GitHub's per-file asset limit.
- Added SHA256 checksums for the reconstructed ISO files.
- Added detailed release notes and manual/tag-based release publishing.

## Important build status

This is currently a branded repack of upstream Debian Live media. AetherOS project files are added as separate files inside the ISO under /AETHEROS/. The current workflow does not yet replace the Debian live root filesystem or install the repository's chroot hooks, package lists, AetherHub, or wallpapers into the running live environment. Full live-build integration remains a separate development step.

Test in a virtual machine before installing on physical hardware.

AetherOS is an independent project and is not affiliated with Debian.
