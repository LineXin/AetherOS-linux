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
sudo rm -rf "$WORK/squashfs-root" "$WORK/filesystem.squashfs" "$WORK/filesystem.squashfs.new"

cd "$WORK"
echo "Downloading official Debian Live checksums..."
curl -fL --retry 4 --retry-delay 3 "$BASE_URL/SHA256SUMS" -o SHA256SUMS

desktop="xfce"
upper="XFCE"
iso_name="debian-live-${DEBIAN_VERSION}-amd64-${desktop}.iso"
source_iso="$WORK/$iso_name"
output_name="AetherOS-${DEBIAN_VERSION}-amd64-${upper}.iso"
output_iso="$OUT/$output_name"

echo "Downloading Debian Live ${DEBIAN_VERSION} (${upper})..."
curl -fL --retry 4 --retry-delay 3 "$BASE_URL/$iso_name" -o "$source_iso"

echo "Verifying upstream SHA256..."
grep -E "[[:space:]]${iso_name//./\\.}$" SHA256SUMS | sha256sum --check -

echo "Extracting live/filesystem.squashfs..."
xorriso -osirrox on -indev "$source_iso" -extract /live/filesystem.squashfs "$WORK/filesystem.squashfs"

echo "Unpacking squashfs root..."
sudo unsquashfs -d "$WORK/squashfs-root" "$WORK/filesystem.squashfs"
rm -f "$WORK/filesystem.squashfs"

echo "Applying config/includes.chroot/..."
sudo cp -a "$ROOT/config/includes.chroot/." "$WORK/squashfs-root/"

echo "Running live chroot hooks..."
for hook in "$ROOT"/config/hooks/live/*.hook.chroot; do
  [ -f "$hook" ] || continue
  hook_name="$(basename "$hook")"
  echo "  -> $hook_name"
  sudo install -m 0755 "$hook" "$WORK/squashfs-root/tmp/$hook_name"
  sudo chroot "$WORK/squashfs-root" /bin/sh "/tmp/$hook_name"
  sudo rm -f "$WORK/squashfs-root/tmp/$hook_name"
done

echo "Repacking filesystem.squashfs..."
sudo mksquashfs "$WORK/squashfs-root" "$WORK/filesystem.squashfs.new" -comp xz -noappend
sudo rm -rf "$WORK/squashfs-root"

echo "Building ${output_name}..."
xorriso -indev "$source_iso" -outdev "$output_iso" \
  -update "$WORK/filesystem.squashfs.new" /live/filesystem.squashfs \
  -map "$ROOT/README.md" /AETHEROS-README.txt \
  -map "$BRANDING/aetheros.txt" /AETHEROS/branding/aetheros.txt \
  -map "$BRANDING/aetheros-logo.svg" /AETHEROS/branding/aetheros-logo.svg \
  -map "$BRANDING/aetheros-wallpaper-mountain.svg" /AETHEROS/branding/aetheros-wallpaper-mountain.svg \
  -map "$BRANDING/aetheros-wallpaper-abstract.svg" /AETHEROS/branding/aetheros-wallpaper-abstract.svg \
  -boot_image any replay

rm -f "$WORK/filesystem.squashfs.new" "$source_iso"
test -s "$output_iso"

(cd "$OUT" && sha256sum "$output_name" >> SHA256SUMS)
echo "Splitting $output_name into GitHub Release-compatible chunks..."
split --bytes=1900M --numeric-suffixes=1 --suffix-length=2 "$output_iso" "$OUT/$output_name.part-"
rm -f "$output_iso"

echo "AetherOS XFCE Live ISO is ready for GitHub Releases."
