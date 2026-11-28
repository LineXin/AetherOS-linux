#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/output"
WORK="$ROOT/work-repack"
VERSION="13.8.0"

DE="${1:-${AETHEROS_DE:-xfce}}"
DE="$(printf '%s' "$DE" | tr '[:lower:]' '[:upper:]' | tr '[:upper:]' '[:lower:]')"
case "$DE" in
  xfce|gnome) ;;
  *)
    echo "ERROR: Unsupported desktop environment '$DE'. Choose 'xfce' or 'gnome'." >&2
    exit 2
    ;;
esac

DE_UPPER="$(printf '%s' "$DE" | tr '[:lower:]' '[:upper:]')"
ISO_NAME="AetherOS-${VERSION}-amd64-${DE_UPPER}.iso"

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  SUDO="sudo"
fi

# Find latest release containing parts for this DE
ASSET_URLS=""
if [ -n "${GITHUB_REPOSITORY:-}" ]; then
  ASSET_URLS="$(python3 - "$GITHUB_REPOSITORY" "$ISO_NAME" <<'PY' || true
import json, os, sys, urllib.request

repo, iso_name = sys.argv[1], sys.argv[2]
req = urllib.request.Request(f"https://api.github.com/repos/{repo}/releases?per_page=10")
tok = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
if tok:
    req.add_header("Authorization", f"Bearer {tok}")
req.add_header("Accept", "application/vnd.github+json")
releases = json.loads(urllib.request.urlopen(req, timeout=20).read().decode())
prefix = iso_name + ".part-"
for rel in releases:
    parts = [a for a in rel.get("assets", []) if a["name"].startswith(prefix)]
    if parts:
        parts.sort(key=lambda a: a["name"])
        for a in parts:
            print(a["browser_download_url"])
        sys.exit(0)
PY
)"
fi

if [ -z "$ASSET_URLS" ]; then
  echo "No existing release found for $ISO_NAME; falling back to full live-build..."
  exec bash "$ROOT/scripts/build.sh" "$DE"
fi

if [ "$DE" = "gnome" ] && command -v cargo >/dev/null 2>&1 && [ -f "$ROOT/aetherhub/Cargo.toml" ]; then
  echo "Building AetherHub (Rust + GTK4)..."
  cargo build --release --manifest-path "$ROOT/aetherhub/Cargo.toml"
  install -D -m 0755 "$ROOT/aetherhub/target/release/aetherhub" \
    "$ROOT/config/includes.chroot/usr/local/bin/aetherhub"
fi

mkdir -p "$OUT" "$WORK"
rm -f "$OUT"/*.iso "$OUT"/*.part-* "$OUT/SHA256SUMS"
$SUDO rm -rf "$WORK/squashfs-root" "$WORK/source.iso" "$WORK/filesystem.squashfs" "$WORK/filesystem.squashfs.new"

echo "Downloading latest $ISO_NAME parts..."
i=1
for url in $ASSET_URLS; do
  part_file="$(printf '%s/part-%02d' "$WORK" "$i")"
  echo "  -> $url"
  curl -fL --retry 4 --retry-delay 3 "$url" -o "$part_file"
  i=$((i + 1))
done
cat "$WORK"/part-* > "$WORK/source.iso"
rm -f "$WORK"/part-*

echo "Extracting live/filesystem.squashfs..."
xorriso -osirrox on -indev "$WORK/source.iso" -extract /live/filesystem.squashfs "$WORK/filesystem.squashfs"

echo "Unpacking squashfs..."
$SUDO unsquashfs -d "$WORK/squashfs-root" "$WORK/filesystem.squashfs"
rm -f "$WORK/filesystem.squashfs"

echo "Overlaying config/includes.chroot/..."
$SUDO cp -a "$ROOT/config/includes.chroot/." "$WORK/squashfs-root/"
if [ "$DE" != "gnome" ]; then
  $SUDO rm -f "$WORK/squashfs-root/usr/local/bin/aetherhub" \
              "$WORK/squashfs-root/usr/share/applications/aetherhub.desktop"
fi

# Install any newly added packages not yet present in the base squashfs
PKGS_TO_INSTALL=""
for listfile in "$ROOT/config/packages/common.txt" "$ROOT/config/packages/${DE}.txt"; do
  [ -f "$listfile" ] || continue
  while IFS= read -r pkg; do
    pkg="${pkg%%#*}"
    pkg="$(printf '%s' "$pkg" | xargs)"
    [ -z "$pkg" ] && continue
    if ! $SUDO chroot "$WORK/squashfs-root" dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
      PKGS_TO_INSTALL="$PKGS_TO_INSTALL $pkg"
    fi
  done < "$listfile"
done

$SUDO cp -L /etc/resolv.conf "$WORK/squashfs-root/etc/resolv.conf"
if [ -n "$PKGS_TO_INSTALL" ]; then
  echo "Installing missing packages into squashfs:$PKGS_TO_INSTALL"
  $SUDO chroot "$WORK/squashfs-root" env DEBIAN_FRONTEND=noninteractive apt-get update
  $SUDO chroot "$WORK/squashfs-root" env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $PKGS_TO_INSTALL
fi

echo "Running AetherOS hooks..."
for hook in \
  "$ROOT/config/hooks/live/0100-aetheros-branding.hook.chroot" \
  "$ROOT/config/hooks/live/0200-aetheros-defaults.hook.chroot" \
  "$ROOT/config/hooks/live/0300-aetheros-trim.hook.chroot"; do
  [ -f "$hook" ] || continue
  hook_name="$(basename "$hook")"
  echo "  -> $hook_name"
  $SUDO install -m 0755 "$hook" "$WORK/squashfs-root/tmp/$hook_name"
  $SUDO chroot "$WORK/squashfs-root" /bin/sh "/tmp/$hook_name"
  $SUDO rm -f "$WORK/squashfs-root/tmp/$hook_name"
done

echo "Repacking filesystem.squashfs..."
$SUDO mksquashfs "$WORK/squashfs-root" "$WORK/filesystem.squashfs.new" -comp gzip -b 1M -processors "$(nproc)" -noappend
$SUDO rm -rf "$WORK/squashfs-root"

OUTPUT_ISO="$OUT/$ISO_NAME"
echo "Updating ISO image..."
xorriso -indev "$WORK/source.iso" -outdev "$OUTPUT_ISO" \
  -update "$WORK/filesystem.squashfs.new" /live/filesystem.squashfs \
  -boot_image any replay

rm -f "$WORK/filesystem.squashfs.new" "$WORK/source.iso"
test -s "$OUTPUT_ISO"

(cd "$OUT" && sha256sum "$ISO_NAME" >> SHA256SUMS)
echo "Splitting $ISO_NAME into GitHub Release-compatible chunks..."
split --bytes=1900M --numeric-suffixes=1 --suffix-length=2 "$OUTPUT_ISO" "$OUT/$ISO_NAME.part-"
rm -f "$OUTPUT_ISO"

echo "Fast repack complete for $ISO_NAME."
