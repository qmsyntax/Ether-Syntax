#!/usr/bin/env bash
# Runs the combat-review probe over a list of configurations, ONE Godot at a time, appending each
# run's PROBE json line to results.jsonl. Usage: bash batch.sh <configs-file>   (one arg string per line)
SP="$(cd "$(dirname "$0")" && pwd -W 2>/dev/null || pwd)"
G="$(ls "$LOCALAPPDATA"/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_*/Godot_v4.7.2-stable_win64_console.exe | head -1)"
GAME="E:/Code/lifesteal-crawler/game"
while IFS= read -r cfg; do
  [ -z "$cfg" ] && continue
  case "$cfg" in \#*) continue;; esac
  start=$(date +%s)
  line=$(timeout 1500 "$G" --headless --fixed-fps 60 --path "$GAME" -s "$SP/run.gd" -- $cfg 2>&1 | tee -a "$SP/last-run.log" | grep "^PROBE {")
  echo "$cfg => $(( $(date +%s) - start ))s" >> "$SP/batch-times.log"
  if [ -n "$line" ]; then echo "${line#PROBE }" >> "$SP/results.jsonl"; else echo "{\"failed\": \"$cfg\"}" >> "$SP/results.jsonl"; fi
done < "$1"
echo BATCH DONE
