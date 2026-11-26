#!/usr/bin/env bash
set -euo pipefail
if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <parts-prefix> <output.iso>" >&2
  echo "Example: $0 AetherOS-13.8.0-amd64-XFCE.iso.part- AetherOS-13.8.0-amd64-XFCE.iso" >&2
  exit 2
fi
prefix="$1"
output="$2"
shopt -s nullglob
parts=( "${prefix}"* )
if [ "${#parts[@]}" -eq 0 ]; then
  echo "No parts found for prefix: $prefix" >&2
  exit 1
fi
cat "${parts[@]}" > "$output"
echo "Reconstructed: $output"
