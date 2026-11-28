#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/output"
BUILD_DIR="$ROOT/build-lb"
VERSION="13.8.0"
OUTPUT_NAME="AetherOS-${VERSION}-amd64-XFCE.iso"
OUTPUT_ISO="$OUT/$OUTPUT_NAME"

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  SUDO="sudo"
fi

mkdir -p "$OUT" "$BUILD_DIR"
rm -f "$OUT"/*.iso "$OUT"/*.part-* "$OUT/SHA256SUMS"

bash "$ROOT/scripts/prepare-live-build.sh"

cd "$BUILD_DIR"
$SUDO lb clean --purge || true
rm -rf config auto local
cp -a "$ROOT/config" "$BUILD_DIR/config"

export MKSQUASHFS_OPTIONS="-comp zstd -Xcompression-level 10 -b 1M -processors $(nproc)"

lb config \
  --mode debian \
  --distribution trixie \
  --architectures amd64 \
  --archive-areas "main contrib non-free-firmware" \
  --mirror-bootstrap "http://deb.debian.org/debian" \
  --mirror-chroot "http://deb.debian.org/debian" \
  --mirror-binary "http://deb.debian.org/debian" \
  --binary-images iso-hybrid \
  --bootappend-live "boot=live components username=aetheros user-fullname=AetherOS hostname=aetheros quiet splash" \
  --iso-application "AetherOS" \
  --iso-publisher "AetherOS" \
  --iso-volume "AetherOS-XFCE" \
  --compression gzip \
  --apt-recommends false \
  --memtest none \
  --win32-loader false \
  --firmware-binary false

$SUDO lb build

BUILT_ISO="$(find "$BUILD_DIR" -maxdepth 1 -name '*.iso' -print -quit)"
if [ -z "$BUILT_ISO" ] || [ ! -s "$BUILT_ISO" ]; then
  echo "ERROR: live-build did not produce an ISO." >&2
  exit 1
fi

mv "$BUILT_ISO" "$OUTPUT_ISO"
(cd "$OUT" && sha256sum "$OUTPUT_NAME" >> SHA256SUMS)

echo "Splitting $OUTPUT_NAME into GitHub Release-compatible chunks..."
split --bytes=1900M --numeric-suffixes=1 --suffix-length=2 "$OUTPUT_ISO" "$OUT/$OUTPUT_NAME.part-"
rm -f "$OUTPUT_ISO"

echo "AetherOS XFCE Live ISO is ready."
