#!/usr/bin/env bash
# Runs the combat-review probe (game/tests/combat_review/) over a list of configurations, ONE Godot at a time,
# appending each run's PROBE json line to the output file.
# Usage: bash batch.sh <configs-file> [out.jsonl]   (one arg string per line; # starts a comment)
HERE="$(cd "$(dirname "$0")" && pwd)"
GAME="$(cd "$HERE/../../game" && (pwd -W 2>/dev/null || pwd))"
OUT="${2:-$HERE/results.jsonl}"
LOGS="$(dirname "$OUT")"
GODOT_SH="$HERE/../test/godot.sh"      # finds the exe and holds the machine-wide lock: one Godot at a time
while IFS= read -r cfg; do
  cfg="${cfg%$'\r'}"
  [ -z "$cfg" ] && continue
  case "$cfg" in \#*) continue;; esac
  start=$(date +%s)
  line=$(GODOT_TIMEOUT=1500 bash "$GODOT_SH" --headless --fixed-fps 60 --path "$GAME" -s res://tests/combat_review/run.gd -- $cfg < /dev/null 2>&1 | tee -a "$LOGS/last-run.log" | grep "^PROBE {")
  echo "$cfg => $(( $(date +%s) - start ))s" >> "$LOGS/batch-times.log"
  if [ -n "$line" ]; then echo "${line#PROBE }" >> "$OUT"; else echo "{\"failed\": \"$cfg\"}" >> "$OUT"; fi
done < "$1"
echo BATCH DONE
