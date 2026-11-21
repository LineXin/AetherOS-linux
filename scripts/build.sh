#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/output"
WORK="$ROOT/work"
ISO_URL="https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-13.7.0-amd64-netinst.iso"

mkdir -p "$OUT" "$WORK"
cd "$WORK"

echo "Downloading Debian 13 installer ISO..."
curl -fL --retry 3 "$ISO_URL" -o debian-netinst.iso

echo "Preparing AetherOS-branded installer prototype..."
mkdir -p overlay
cp "$ROOT/installer/preseed/aetheros.cfg" overlay/aetheros-preseed.cfg
cp "$ROOT/README.md" overlay/AETHEROS-README.txt

# Prototype: preserve the official Debian installer and add project files
# as a separate ISO payload. Full installer integration is a future milestone.
xorriso -indev debian-netinst.iso -outdev "$OUT/AetherOS-13-amd64-Installer.iso" \
  -map overlay/aetheros-preseed.cfg /AETHEROS-PRESEED.cfg \
  -map overlay/AETHEROS-README.txt /AETHEROS-README.txt \
  -boot_image any replay

echo "ISO created: $OUT/AetherOS-13-amd64-Installer.iso"
