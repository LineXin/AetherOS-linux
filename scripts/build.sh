#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/output"
WORK="$ROOT/work"
DEBIAN_VERSION="13.8.0"
BASE_URL="https://cdimage.debian.org/debian-cd/current-live/amd64/iso-hybrid"
SUMS_URL="$BASE_URL/SHA256SUMS"
BRANDING="$ROOT/config/includes.chroot/usr/share/aetheros/branding"

mkdir -p "$OUT" "$WORK"
rm -f "$OUT"/*.iso
cd "$WORK"

echo "Downloading official Debian Live SHA256SUMS..."
curl -fL --retry 4 --retry-delay 3 "$SUMS_URL" -o SHA256SUMS

for desktop in xfce kde; do
    upper="$(printf '%s' "$desktop" | tr '[:lower:]' '[:upper:]')"
    iso_name="debian-live-${DEBIAN_VERSION}-amd64-${desktop}.iso"
    source_iso="$WORK/$iso_name"
    output_iso="$OUT/AetherOS-${DEBIAN_VERSION}-amd64-${upper}.iso"

    echo "Downloading Debian Live ${DEBIAN_VERSION} (${upper})..."
    curl -fL --retry 4 --retry-delay 3 "$BASE_URL/$iso_name" -o "$source_iso"

    echo "Verifying SHA256 for $iso_name..."
    grep -E "[[:space:]]${iso_name//./\\.}$" SHA256SUMS | sha256sum --check -

    echo "Adding AetherOS project branding to ${upper} live image..."
    xorriso -indev "$source_iso" -outdev "$output_iso" \
        -map "$ROOT/README.md" /AETHEROS-README.txt \
        -map "$BRANDING/aetheros.txt" /AETHEROS/branding/aetheros.txt \
        -map "$BRANDING/aetheros-logo.svg" /AETHEROS/branding/aetheros-logo.svg \
        -map "$BRANDING/aetheros-wallpaper-mountain.svg" /AETHEROS/branding/aetheros-wallpaper-mountain.svg \
        -map "$BRANDING/aetheros-wallpaper-abstract.svg" /AETHEROS/branding/aetheros-wallpaper-abstract.svg \
        -boot_image any replay

    test -s "$output_iso"
    echo "Created: $output_iso"
done

echo "Both AetherOS Live ISO images were created successfully."
