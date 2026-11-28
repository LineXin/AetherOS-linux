# AetherOS Linux

A Debian-based Linux distribution featuring a custom system identity, **XFCE** and **GNOME** desktop editions, Fastfetch branding, original SVG wallpapers, and **AetherHub** — a native GTK4 settings center.

---

## Highlights

- **Custom Identity** — Branded `os-release`, `lsb-release`, GRUB distributor, `/etc/issue`, and `aetheros` hostname integrated directly into the live squashfs root.
- **XFCE & GNOME Editions** — Pre-configured XFCE and GNOME desktops with custom AetherOS wallpapers and autostart defaults.
- **AetherHub (GTK4)** — Native Rust/GTK4 settings and system control center (`aetherhub`).
- **Fastfetch Integration** — Custom ASCII/logo greeting and system summary on shell startup.
- **Automated CI Releases** — GitHub Actions builds the Live ISO, splits it into GitHub Release-compatible chunks, and publishes `SHA256SUMS`.

---

## Repository Layout

| Path | Purpose |
| :--- | :--- |
| `aetherhub/` | Native GTK4/Rust settings center (`aetherhub` v0.4.0) |
| `config/includes.chroot/` | Files overlaid onto the live root filesystem (`/etc`, `/usr/share/aetheros`, `/usr/local/bin`, etc.) |
| `config/hooks/live/` | Chroot hooks executed during ISO build (`0100-aetheros-branding`, `0200-aetheros-defaults`) |
| `config/packages/` | Package lists for common, XFCE, GNOME, and AetherHub components |
| `scripts/build.sh` | Downloads Debian 13.8.0 Live, unpacks squashfs, applies chroot branding/hooks, and repacks the ISO |
| `scripts/join-release-iso.sh` | Helper to reconstruct split `.iso.part-*` files |
| `.github/workflows/` | CI workflow for building and publishing GitHub Releases |

---

## Downloading & Reconstructing a Release ISO

GitHub Releases host the ISO in split parts due to the 2 GB per-file limit.

1. Download all `AetherOS-13.8.0-amd64-<EDITION>.iso.part-*` files (`XFCE` or `GNOME`) and `SHA256SUMS` from the [Releases](../../releases) page.
2. Reconstruct and verify the ISO:

```bash
cat AetherOS-13.8.0-amd64-XFCE.iso.part-* > AetherOS-13.8.0-amd64-XFCE.iso
sha256sum --ignore-missing -c SHA256SUMS
```

Or use the included helper script:

```bash
bash scripts/join-release-iso.sh AetherOS-13.8.0-amd64-XFCE.iso.part- AetherOS-13.8.0-amd64-XFCE.iso
```

---

## Building Locally

Requires a Debian/Ubuntu environment (native or WSL) with `curl`, `xorriso`, `squashfs-tools`, and `sudo` access:

```bash
bash scripts/build.sh
```

The resulting split ISO parts and `SHA256SUMS` will be written to `output/`.

---

## CI / Automated Publishing

1. Open **Actions** → **Build and publish AetherOS Live ISO**.
2. Click **Run workflow** and specify a release tag (e.g. `v0.1.0`), or push a tag matching `v*`.
3. Once complete, the split ISO parts and `SHA256SUMS` are published to **GitHub Releases**.

---

*AetherOS is an independent project and is not affiliated with Debian.*
