#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
find config/hooks/live -maxdepth 1 -type f -name '*.hook.chroot' -exec chmod 0755 {} +
find config/hooks/normal -maxdepth 1 -type f -name '*.hook.binary' -exec chmod 0755 {} +
chmod 0755 config/includes.chroot/usr/local/sbin/aetheros-tune
chmod 0755 config/includes.chroot/usr/local/bin/aetherhub
chmod 0755 config/includes.chroot/usr/local/bin/aetheros-wallpaper
chmod 0755 config/includes.chroot/usr/local/bin/aetheros-welcome
echo "AetherOS live-build file modes prepared."
