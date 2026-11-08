#!/usr/bin/env bash
# Run the performance probe (game/tests/perf_probe.tscn) over every scene at the default and the furthest zoom,
# REPEAT times each, one Godot at a time, and print each run's PERF line plus the median of each scene/zoom.
# Usage: bash tools/perf/perf_all.sh [log dir] [repeat=3] [scenes="wall stubble town nether skills"] [zooms="default far"]
# GODOT (env) is the command used to run Godot (default: the winget console exe); give it a lock wrapper when
# other Godot runs share the machine. Windowed: hands off while it runs - and close what you can, other
# programs skew the numbers.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
GAME="$HERE/../../game"
LOGS="${1:-$HERE/../../shots/perf}"
REPEAT="${2:-3}"
SCENES="${3:-wall stubble town nether skills}"
ZOOMS="${4:-default far}"
GODOT="${GODOT:-$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
mkdir -p "$LOGS"
for s in $SCENES; do
  for z in $ZOOMS; do
    for i in $(seq 1 "$REPEAT"); do
      log="$LOGS/$s-$z-$i.log"
      $GODOT --quit-after 200000 --path "$GAME" res://tests/perf_probe.tscn -- --scene="$s" --zoom="$z" ${PERF_ARGS:-} > "$log" 2>&1
      grep -h "^PERF" "$log"
    done
  done
done
python "$HERE/perf_median.py" "$LOGS"
