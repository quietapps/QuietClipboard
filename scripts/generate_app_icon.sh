#!/usr/bin/env bash
# Regenerate AppIcon PNGs from the master SVG.
# Requires: rsvg-convert (brew install librsvg)
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
SVG="$ROOT/.claude/skills/quiet-apps-design/assets/app-icons/quiet-clipboard.svg"
OUT="$ROOT/QuietClipboard/Assets.xcassets/AppIcon.appiconset"

mkdir -p "$OUT"
for s in 16 32 64 128 256 512 1024; do
  rsvg-convert -w "$s" -h "$s" "$SVG" -o "$OUT/icon_${s}.png"
done
echo "Wrote PNGs to $OUT"
