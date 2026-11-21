# AetherHub

AetherHub is the planned control center for AetherOS. The first prototype is a small GTK4 application written in Python.

## Current features

- Shows OS, kernel, architecture, CPU, and memory information
- Quick-launch buttons for XFCE Settings, Terminal, and Thunar
- Dark AetherOS-inspired styling

## Debian dependencies

```bash
sudo apt update
sudo apt install python3 python3-gi gir1.2-gtk-4.0
```

## Run from the repository

```bash
python3 aetherhub/src/aetherhub.py
```

## Install into the current user

```bash
bash aetherhub/install.sh
```

Then launch from the application menu or run `aetherhub`.

This is an early prototype. The settings and application-management pages are planned.
