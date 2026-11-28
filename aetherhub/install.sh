#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
BIN="$HOME/.local/bin"
APPS="$HOME/.local/share/applications"

mkdir -p "$BIN" "$APPS"
cargo build --release --manifest-path "$ROOT/Cargo.toml"
install -m 755 "$ROOT/target/release/aetherhub" "$BIN/aetherhub"

cat > "$APPS/aetherhub.desktop" <<'EOF'
[Desktop Entry]
Name=AetherHub
Comment=AetherOS control center
Exec=aetherhub
Icon=preferences-system
Terminal=false
Type=Application
Categories=Settings;System;
EOF

echo "AetherHub (Rust + GTK4) installed to $BIN/aetherhub"
