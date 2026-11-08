#!/usr/bin/env bash
# Run the Godot 4.7.2 console exe with the given arguments, holding the machine-wide lock so only ONE Godot runs at a
# time: every test shares the "Ether Syntax" user dir, and the windowed probes move the real mouse.
#
#   bash tools/test/godot.sh <godot args...>        exit code = Godot's (124 when it ran past the timeout)
#
# The exe and the lock come from tools/release/godot_lock.sh (one copy, shared with the release scripts): the winget
# install under %LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_*\, and the lock directory
# %LOCALAPPDATA%\Temp\ether-syntax-godot.lock (mkdir is atomic; `since` and `who` inside; broken when older than 20
# minutes, aged by the directory's own time until `since` is written). Any script that starts Godot for this project
# goes through here or that helper (run_all.sh, save_kill.sh via GODOT="bash tools/test/godot.sh", the
# combat-review batch, the release scripts).
#   GODOT=<exe file>     use this exe (a GODOT that is not a file - e.g. save_kill.sh's "bash .../godot.sh" - is
#                        ignored here)
#   GODOT_TIMEOUT=<s>    kill Godot after this many seconds (default 1100, under the lock's 20 minutes)
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"

if [ -n "${GODOT:-}" ] && { [ ! -f "$GODOT" ] || [ "$(basename "$GODOT")" = "godot.sh" ]; }; then
  unset GODOT
fi
# shellcheck source=../release/godot_lock.sh
. "$HERE/../release/godot_lock.sh"
if [ -z "${GODOT:-}" ] || [ ! -f "$GODOT" ]; then
  echo "godot.sh: no Godot_v4.7.2-stable_win64_console.exe under %LOCALAPPDATA%/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_*/ (set GODOT=<exe>)" >&2
  exit 127
fi

wait_from=$(date +%s)
godot_lock
waited=$(( $(date +%s) - wait_from ))
echo "$PWD $*" > "$GODOT_LOCK/who"          # the arguments say more than the script's name
if [ "$waited" -gt 1 ]; then
  echo "godot.sh: waited ${waited}s for the lock" >&2
fi
timeout "${GODOT_TIMEOUT:-1100}" "$GODOT" "$@"
