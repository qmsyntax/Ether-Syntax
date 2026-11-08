#!/usr/bin/env bash
# Sourced by the release scripts. Finds the Godot console exe and takes the machine-wide lock that keeps ONE Godot
# (editor build or an exported Ether Syntax) running at a time: they share the "Ether Syntax" user dir, and windowed
# runs move the real mouse. The same lock dir the test wrappers use.
#   GODOT=<path>   use this Godot instead of the winget one
#   godot_lock     take the lock (waits; breaks a lock older than 20 minutes); released when the script exits

if [ -z "${GODOT:-}" ]; then
  _la="${LOCALAPPDATA:-$HOME/AppData/Local}"
  command -v cygpath >/dev/null 2>&1 && _la="$(cygpath -u "$_la")"
  GODOT="$(ls "$_la"/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_*/Godot_v4.7.2-stable_win64_console.exe 2>/dev/null | head -1)"
fi
GODOT_LOCK="${GODOT_LOCK:-/c/Users/qmsyntax/AppData/Local/Temp/ether-syntax-godot.lock}"

godot_lock() {
  local stale_s=1200 age since
  while ! mkdir "$GODOT_LOCK" 2>/dev/null; do
    # The holder writes "since" just after its mkdir: until then (or if it is unreadable) age the lock by the
    # directory's own time, never by 0 - that made a lock taken a moment ago look decades old and get broken.
    since="$(cat "$GODOT_LOCK/since" 2>/dev/null)"
    case "$since" in ''|*[!0-9]*) since="$(stat -c %Y "$GODOT_LOCK" 2>/dev/null || date +%s)";; esac
    age=$(( $(date +%s) - since ))
    if [ "$age" -gt "$stale_s" ]; then
      echo "godot_lock: breaking stale lock (${age}s, holder: $(cat "$GODOT_LOCK/who" 2>/dev/null))" >&2
      rm -rf "$GODOT_LOCK"
      continue
    fi
    sleep 3
  done
  date +%s > "$GODOT_LOCK/since"
  echo "$PWD $0" > "$GODOT_LOCK/who"
  trap 'rm -rf "$GODOT_LOCK"' EXIT INT TERM
}
