#!/usr/bin/env bash
# Run the Godot 4.7.2 console exe with the given arguments, holding a machine-wide lock so only ONE Godot test process
# runs at a time: every test shares the "Ether Syntax" user dir (saves, keybinds, settings), and the windowed probes
# move the real mouse.
#
#   bash tools/test/godot.sh <godot args...>        exit code = Godot's (124 when it ran past the timeout)
#
# The exe is found under %LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_*\ (winget's install), or
# taken from $GODOT. The lock is the directory %LOCALAPPDATA%\Temp\ether-syntax-godot.lock (mkdir is atomic); it
# holds `since` (epoch seconds) and `who` (the holder's directory and arguments), and is broken when older than
# STALE_S - a holder killed outright leaves it behind. Any script that starts Godot for this project must go
# through here (tools/test/run_all.sh and tools/combat-review/batch.sh do).
#   GODOT=<exe>          use this exe
#   GODOT_TIMEOUT=<s>    kill Godot after this many seconds (default 1100)
set -u

to_unix() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -u "$1"; else printf '%s\n' "$1"; fi
}

LOCAL="$(to_unix "${LOCALAPPDATA:-$HOME/AppData/Local}")"

find_godot() {
  if [ -n "${GODOT:-}" ]; then
    printf '%s\n' "$GODOT"
    return 0
  fi
  local exe
  for exe in "$LOCAL"/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_*/Godot_v4.7.2-stable_win64_console.exe; do
    if [ -f "$exe" ]; then
      printf '%s\n' "$exe"
      return 0
    fi
  done
  return 1
}

G="$(find_godot)" || {
  echo "godot.sh: no Godot_v4.7.2-stable_win64_console.exe under $LOCAL/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_*/ (set GODOT=<exe>)" >&2
  exit 127
}

LOCK="$LOCAL/Temp/ether-syntax-godot.lock"
STALE_S=1200
waited=0
wait_from=$(date +%s)
while ! mkdir "$LOCK" 2>/dev/null; do
  if [ -f "$LOCK/since" ]; then
    age=$(( $(date +%s) - $(cat "$LOCK/since" 2>/dev/null || echo 0) ))
    if [ "$age" -gt "$STALE_S" ]; then
      echo "godot.sh: breaking stale lock (${age}s, holder: $(cat "$LOCK/who" 2>/dev/null))" >&2
      rm -rf "$LOCK"
      continue
    fi
  fi
  if [ "$waited" -eq 0 ]; then
    echo "godot.sh: waiting for the Godot lock (holder: $(cat "$LOCK/who" 2>/dev/null))" >&2
    waited=1
  fi
  sleep 3
done
if [ "$waited" -eq 1 ]; then
  echo "godot.sh: waited $(( $(date +%s) - wait_from ))s for the lock" >&2
fi
date +%s > "$LOCK/since"
echo "$PWD $*" > "$LOCK/who"
trap 'rm -rf "$LOCK"' EXIT INT TERM
timeout "${GODOT_TIMEOUT:-1100}" "$G" "$@"
