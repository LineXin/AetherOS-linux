# AetherOS Linux — Release

A clean, fast Debian-based Linux distribution with a unified dark aesthetic, custom branding, and a ready-to-use desktop experience out of the box.

## Available Editions

- **XFCE Edition** (`AetherOS-13.8.0-amd64-XFCE.iso`) — Lightweight and fast desktop for everyday use and older hardware.
- **GNOME Edition** (`AetherOS-13.8.0-amd64-GNOME.iso`) — Modern GNOME desktop with **AetherHub**, dark theme by default, and pre-installed extensions.

---

## What's New

- **Built from Scratch (`live-build`)**: Moved from simple ISO repacking to a full custom Debian 13 (Trixie) Live system where all AetherOS themes, wallpapers, and tools work immediately on boot.
- **AetherHub Settings Center (GNOME)**: Rewritten in Rust + GTK4 with a consistent dark interface, custom app icon, and quick controls for performance, services, network, and appearance.
- **Bilingual Welcome Screen (EN / RU)**: Appears in the Live session with a one-click language switch, quick launch for AetherHub, and an "Install System" button (shows only once after installation).
- **Graphical System Installer (Calamares)**: Fully branded AetherOS installer with custom styling, desktop selection, and reliable disk/user setup.
- **GNOME Polish & Extensions**: Default dark mode, custom AetherOS wallpapers, Nerd Fonts symbols, and pre-configured **AppIndicator**, **Dash2Dock Lite**, and **Blur My Shell** extensions.
- **Complete System Branding**: Custom boot splash, lockscreen/login logo, Fastfetch terminal greeting, and AetherOS system identity in Settings.

---

## How to Download and Prepare the ISO

Because GitHub Releases limits single files to under 2 GiB, larger ISOs are split into numbered `.part-*` files.

1. Download all `AetherOS-13.8.0-amd64-<EDITION>.iso.part-*` files for your chosen edition (`XFCE` or `GNOME`), plus `SHA256SUMS`.
2. Put them in the same folder and combine them into one `.iso` file:

```bash
# Example for GNOME (replace GNOME with XFCE for the XFCE edition)
cat AetherOS-13.8.0-amd64-GNOME.iso.part-* > AetherOS-13.8.0-amd64-GNOME.iso
sha256sum --ignore-missing -c SHA256SUMS
```

Or use the helper script from the repository:

```bash
bash scripts/join-release-iso.sh AetherOS-13.8.0-amd64-GNOME.iso.part- AetherOS-13.8.0-amd64-GNOME.iso
```

3. Flash the `.iso` to a USB drive (using Balena Etcher, Rufus, or `dd`) or test it in a virtual machine.

---

*AetherOS is an independent project and is not affiliated with Debian.*
