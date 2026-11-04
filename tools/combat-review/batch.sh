#!/usr/bin/env bash
# Runs the combat-review probe (game/tests/combat_review/) over a list of configurations, ONE Godot at a time,
# appending each run's PROBE json line to the output file.
# Usage: bash batch.sh <configs-file> [out.jsonl]   (one arg string per line; # starts a comment)
HERE="$(cd "$(dirname "$0")" && pwd)"
GAME="$(cd "$HERE/../../game" && (pwd -W 2>/dev/null || pwd))"
OUT="${2:-$HERE/results.jsonl}"
LOGS="$(dirname "$OUT")"
G="$(ls "$LOCALAPPDATA"/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_*/Godot_v4.7.2-stable_win64_console.exe | head -1)"
while IFS= read -r cfg; do
  cfg="${cfg%$'\r'}"
  [ -z "$cfg" ] && continue
  case "$cfg" in \#*) continue;; esac
  start=$(date +%s)
  line=$(timeout 1500 "$G" --headless --fixed-fps 60 --path "$GAME" -s res://tests/combat_review/run.gd -- $cfg 2>&1 | tee -a "$LOGS/last-run.log" | grep "^PROBE {")
  echo "$cfg => $(( $(date +%s) - start ))s" >> "$LOGS/batch-times.log"
  if [ -n "$line" ]; then echo "${line#PROBE }" >> "$OUT"; else echo "{\"failed\": \"$cfg\"}" >> "$OUT"; fi
done < "$1"
echo BATCH DONE
