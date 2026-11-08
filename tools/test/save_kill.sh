#!/usr/bin/env bash
# A save survives a kill mid-write (Phase 0). Each round starts game/tests/save_kill_probe.tscn with
# --write, which writes a large save, the key bindings and the settings in a loop until a watcher
# thread kills the process at a random moment (OS.kill on itself), then starts it again with
# --verify, which must load all three whole. Everything is in user://kill_probe/, never the
# player's own files.
#
# Usage: tools/test/save_kill.sh <game dir> [rounds=5]
# GODOT is the command that runs Godot (default: "godot"); point it at the one-Godot-at-a-time lock
# wrapper, e.g. GODOT="bash /path/to/godot.sh". Exit 0 when every round passes.
set -u
GAME="${1:?usage: save_kill.sh <game dir> [rounds]}"
ROUNDS="${2:-5}"
GODOT="${GODOT:-godot}"
failed=0
for i in $(seq 1 "$ROUNDS"); do
  extra=""
  [ "$i" -eq 1 ] && extra="--fresh"
  wlog=$($GODOT --headless --path "$GAME" res://tests/save_kill_probe.tscn -- --write $extra 2>&1)
  killed=$(printf '%s\n' "$wlog" | grep -o "killed during stage '[a-z]*'" | tail -1)
  vlog=$($GODOT --headless --path "$GAME" res://tests/save_kill_probe.tscn -- --verify 2>&1)
  verdict=$(printf '%s\n' "$vlog" | grep -E '^SAVEKILL: (PASS|FAIL)' | tail -1)
  echo "round $i: ${killed:-NOT KILLED} -> ${verdict:-no verdict}"
  printf '%s\n' "$vlog" | grep '^SAVEKILL:   '
  if [ -z "$killed" ] || [ "$verdict" != "SAVEKILL: PASS" ]; then failed=1; fi
done
if [ "$failed" -eq 0 ]; then echo "SAVEKILL ALL: PASS"; else echo "SAVEKILL ALL: FAIL"; fi
exit "$failed"
