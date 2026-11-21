#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/.local/share/aetherhub"
BIN="$HOME/.local/bin"
APPS="$HOME/.local/share/applications"
mkdir -p "$DEST" "$BIN" "$APPS"
install -m 755 "$ROOT/src/aetherhub.py" "$DEST/aetherhub.py"
cat > "$BIN/aetherhub" <<'EOF'
#!/usr/bin/env bash
exec /usr/bin/python3 "$HOME/.local/share/aetherhub/aetherhub.py" "$@"
EOF
chmod 755 "$BIN/aetherhub"
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
echo "AetherHub installed for this user."
echo "If ~/.local/bin is not in PATH, launch with: ~/.local/bin/aetherhub"
