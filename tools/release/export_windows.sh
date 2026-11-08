#!/usr/bin/env bash
# Export the Windows build with the "Windows Desktop" preset (game/export_presets.cfg):
#   build/windows/EtherSyntax.exe          the game, PCK embedded (one file to copy)
#   build/windows/EtherSyntax.console.exe  the same game with a console window, for reading its output
#   build/windows/version.txt              the stamp it was built from (application/config/version)
# Needs the Godot 4.7.2 export templates in %APPDATA%\Godot\export_templates\4.7.2.stable\.
# Usage: bash tools/release/export_windows.sh          (exit code 0 = the exe exists and the export said nothing bad)
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
GAME="$ROOT/game"
OUT="$ROOT/build/windows"
. "$HERE/godot_lock.sh"
[ -x "$GODOT" ] || { echo "export: Godot 4.7.2 console exe not found (set GODOT=...)"; exit 2; }

_ad="${APPDATA:-$HOME/AppData/Roaming}"
command -v cygpath >/dev/null 2>&1 && _ad="$(cygpath -u "$_ad")"
[ -f "$_ad/Godot/export_templates/4.7.2.stable/windows_release_x86_64.exe" ] \
  || { echo "export: no 4.7.2.stable export templates under $_ad/Godot/export_templates"; exit 2; }

stamp="$(sed -n 's/^config\/version="\(.*\)"/\1/p' "$GAME/project.godot")"
echo "export: Ether Syntax ${stamp:-<no stamp>} -> $OUT"
rm -rf "$OUT"
mkdir -p "$OUT"
LOG="$OUT/../export-windows.log"

# The exe's Windows file / product version must be numeric (X.Y.Z.W), so the stamp's "+sha" cannot go there: for
# the export only, the preset gets "X.Y.Z.0" from the stamp, and the committed preset is put back afterwards.
num="$(echo "${stamp:-0.0.0}" | sed 's/+.*//; s/[^0-9.]//g')"
[ -n "$num" ] || num="0.0.0"
PRESET="$GAME/export_presets.cfg"
cp "$PRESET" "$OUT/../export_presets.cfg.orig"

godot_lock
trap 'cp "$OUT/../export_presets.cfg.orig" "$PRESET"; rm -rf "$GODOT_LOCK"' EXIT INT TERM
sed -i "s/^application\/file_version=.*/application\/file_version=\"$num.0\"/; s/^application\/product_version=.*/application\/product_version=\"$num.0\"/" "$PRESET"
"$GODOT" --headless --path "$GAME" --import > "$LOG" 2>&1
"$GODOT" --headless --path "$GAME" --export-release "Windows Desktop" "$OUT/EtherSyntax.exe" >> "$LOG" 2>&1
rc=$?
cp "$OUT/../export_presets.cfg.orig" "$PRESET"
echo "${stamp:-dev}" > "$OUT/version.txt"

grep -E '^WARNING' "$LOG" | sort | uniq -c
bad="$(grep -E 'ERROR' "$LOG" | grep -v 'leaked at exit' || true)"
if [ $rc -ne 0 ] || [ ! -s "$OUT/EtherSyntax.exe" ] || [ -n "$bad" ]; then
  echo "export: FAILED (exit $rc) - see $LOG"
  [ -n "$bad" ] && echo "$bad"
  exit 1
fi
ls -l "$OUT"
echo "export: OK  $(du -h "$OUT/EtherSyntax.exe" | cut -f1)  $OUT/EtherSyntax.exe"
