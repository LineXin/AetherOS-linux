#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/output"
BUILD_DIR="$ROOT/build-lb"
VERSION="13.8.0"

DE="${1:-${AETHEROS_DE:-xfce}}"
DE="$(printf '%s' "$DE" | tr '[:upper:]' '[:lower:]')"
case "$DE" in
  xfce|gnome) ;;
  *)
    echo "ERROR: Unsupported desktop environment '$DE'. Choose 'xfce' or 'gnome'." >&2
    exit 2
    ;;
esac

DE_UPPER="$(printf '%s' "$DE" | tr '[:lower:]' '[:upper:]')"
OUTPUT_NAME="AetherOS-${VERSION}-amd64-${DE_UPPER}.iso"
OUTPUT_ISO="$OUT/$OUTPUT_NAME"

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  SUDO="sudo"
fi

if [ "$DE" = "gnome" ] && command -v cargo >/dev/null 2>&1 && [ -f "$ROOT/aetherhub/Cargo.toml" ]; then
  echo "Building AetherHub (Rust + GTK4)..."
  cargo build --release --manifest-path "$ROOT/aetherhub/Cargo.toml"
  install -D -m 0755 "$ROOT/aetherhub/target/release/aetherhub" \
    "$ROOT/config/includes.chroot/usr/local/bin/aetherhub"
fi

mkdir -p "$OUT" "$BUILD_DIR"
rm -f "$OUT"/*.iso "$OUT"/*.part-* "$OUT/SHA256SUMS"

bash "$ROOT/scripts/prepare-live-build.sh"

cd "$BUILD_DIR"
$SUDO lb clean --purge || true
rm -rf config auto local
cp -a "$ROOT/config" "$BUILD_DIR/config"
if [ "$DE" != "gnome" ]; then
  rm -f "$BUILD_DIR/config/includes.chroot/usr/local/bin/aetherhub" \
        "$BUILD_DIR/config/includes.chroot/usr/share/applications/aetherhub.desktop"
fi
cp -f "$ROOT/config/packages/common.txt" "$BUILD_DIR/config/package-lists/common.list.chroot"
cp -f "$ROOT/config/packages/${DE}.txt" "$BUILD_DIR/config/package-lists/desktop.list.chroot"

export MKSQUASHFS_OPTIONS="-b 1M -processors $(nproc)"

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
  --iso-volume "AetherOS-${DE_UPPER}" \
  --compression gzip \
  --apt-recommends false \
  --memtest none \
  --win32-loader false \
  --firmware-binary false

LOG_FILE="$OUT/lb-build.log"
echo "Running live-build (compact log; full log at $LOG_FILE)..."
set +e
$SUDO lb build 2>&1 | tee "$LOG_FILE" | stdbuf -oL grep -E '^(P:|W:|E:|ERROR)'
LB_RC=${PIPESTATUS[0]}
set -e
if [ "$LB_RC" -ne 0 ]; then
  echo "ERROR: lb build failed (exit $LB_RC). Last 80 lines:" >&2
  tail -n 80 "$LOG_FILE" >&2
  exit "$LB_RC"
fi

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

echo "AetherOS ${DE_UPPER} Live ISO is ready."
