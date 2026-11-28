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
if [ -f "$source_iso" ] && grep -E "[[:space:]]${iso_name//./\\.}$" SHA256SUMS | sha256sum --check - >/dev/null 2>&1; then
  echo "Using cached $iso_name (SHA256 verified)."
else
  rm -f "$source_iso"
  if command -v aria2c >/dev/null 2>&1; then
    aria2c -x 16 -s 16 -k 1M --file-allocation=none -d "$WORK" -o "$iso_name" "$BASE_URL/$iso_name"
  else
    curl -fL --retry 4 --retry-delay 3 "$BASE_URL/$iso_name" -o "$source_iso"
  fi
  echo "Verifying upstream SHA256..."
  grep -E "[[:space:]]${iso_name//./\\.}$" SHA256SUMS | sha256sum --check -
fi

echo "Extracting live/filesystem.squashfs..."
xorriso -osirrox on -indev "$source_iso" -extract /live/filesystem.squashfs "$WORK/filesystem.squashfs"

echo "Unpacking squashfs root..."
sudo unsquashfs -processors "$(nproc)" -d "$WORK/squashfs-root" "$WORK/filesystem.squashfs"
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

echo "Trimming unnecessary files to reduce ISO size..."
sudo rm -rf \
  "$WORK/squashfs-root/var/cache/apt/archives/"*.deb \
  "$WORK/squashfs-root/var/lib/apt/lists/"* \
  "$WORK/squashfs-root/usr/share/doc/"* \
  "$WORK/squashfs-root/usr/share/man/"* \
  "$WORK/squashfs-root/usr/share/info/"* \
  "$WORK/squashfs-root/usr/share/lintian/"* \
  "$WORK/squashfs-root/tmp/"* \
  "$WORK/squashfs-root/var/tmp/"*
if [ -d "$WORK/squashfs-root/usr/share/locale" ]; then
  sudo find "$WORK/squashfs-root/usr/share/locale" -mindepth 1 -maxdepth 1 \
    ! -name 'en*' ! -name 'ru*' ! -name 'locale.alias' -exec rm -rf {} +
fi

echo "Repacking filesystem.squashfs (zstd)..."
sudo mksquashfs "$WORK/squashfs-root" "$WORK/filesystem.squashfs.new" -comp zstd -Xcompression-level 19 -b 1M -processors "$(nproc)" -noappend
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

rm -f "$WORK/filesystem.squashfs.new"
if [ "${KEEP_SOURCE_ISO:-0}" != "1" ]; then
  rm -f "$source_iso"
fi
test -s "$output_iso"

(cd "$OUT" && sha256sum "$output_name" >> SHA256SUMS)
echo "Splitting $output_name into GitHub Release-compatible chunks..."
split --bytes=1900M --numeric-suffixes=1 --suffix-length=2 "$output_iso" "$OUT/$output_name.part-"
rm -f "$output_iso"

echo "AetherOS XFCE Live ISO is ready for GitHub Releases."
