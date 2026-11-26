#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/output"
WORK="$ROOT/work"
DEBIAN_VERSION="13.8.0"
BASE_URL="https://cdimage.debian.org/debian-cd/current-live/amd64/iso-hybrid"
BRANDING="$ROOT/config/includes.chroot/usr/share/aetheros/branding"
mkdir -p "$OUT" "$WORK"
rm -f "$OUT"/*.iso "$OUT"/*.part-* "$OUT/SHA256SUMS"
cd "$WORK"
echo "Downloading official Debian Live checksums..."
curl -fL --retry 4 --retry-delay 3 "$BASE_URL/SHA256SUMS" -o SHA256SUMS
for desktop in xfce kde; do
  upper="$(printf '%s' "$desktop" | tr '[:lower:]' '[:upper:]')"
  iso_name="debian-live-${DEBIAN_VERSION}-amd64-${desktop}.iso"
  source_iso="$WORK/$iso_name"
  output_name="AetherOS-${DEBIAN_VERSION}-amd64-${upper}.iso"
  output_iso="$OUT/$output_name"
  echo "Downloading Debian Live ${DEBIAN_VERSION} (${upper})..."
  curl -fL --retry 4 --retry-delay 3 "$BASE_URL/$iso_name" -o "$source_iso"
  echo "Verifying upstream SHA256..."
  grep -E "[[:space:]]${iso_name//./\\.}$" SHA256SUMS | sha256sum --check -
  echo "Repacking ${upper} image with AetherOS project files..."
  xorriso -indev "$source_iso" -outdev "$output_iso" \
    -map "$ROOT/README.md" /AETHEROS-README.txt \
    -map "$BRANDING/aetheros.txt" /AETHEROS/branding/aetheros.txt \
    -map "$BRANDING/aetheros-logo.svg" /AETHEROS/branding/aetheros-logo.svg \
    -map "$BRANDING/aetheros-wallpaper-mountain.svg" /AETHEROS/branding/aetheros-wallpaper-mountain.svg \
    -map "$BRANDING/aetheros-wallpaper-abstract.svg" /AETHEROS/branding/aetheros-wallpaper-abstract.svg \
    -boot_image any replay
  test -s "$output_iso"
  (cd "$OUT" && sha256sum "$output_name" >> SHA256SUMS)
  echo "Splitting $output_name into GitHub Release-compatible chunks..."
  split --bytes=1900M --numeric-suffixes=1 --suffix-length=2 "$output_iso" "$OUT/$output_name.part-"
  rm -f "$source_iso" "$output_iso"
done
echo "Both Live ISO editions are ready for GitHub Releases."
