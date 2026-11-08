"""Median of the perf probe's PERF lines, per scene and zoom.

Usage: python tools/perf/perf_median.py <log dir> [more dirs...]
Reads every *.log under the given folders, takes each "PERF scene=..." line, groups by scene and zoom and
prints the median of each number as a Markdown table (the shape docs/perf/ uses).
"""
import glob
import os
import statistics
import sys

COLS = ["fps_avg", "fps_low1", "ms_avg", "ms_max", "cpu_render_ms", "gpu_ms", "process_ms", "physics_ms",
        "draw_calls", "draw_calls_max", "objects", "primitives", "ws_mb", "hitches", "startup_hitches", "startup_max_ms", "spawn_ms"]


def main() -> None:
    groups: dict = {}
    for d in sys.argv[1:]:
        for path in sorted(glob.glob(os.path.join(d, "*.log"))):
            with open(path, encoding="utf-8", errors="replace") as f:
                for line in f:
                    if not line.startswith("PERF scene="):
                        continue
                    kv = dict(p.split("=", 1) for p in line.split()[1:] if "=" in p)
                    key = (kv["scene"], kv["zoom"].split("(")[0])
                    groups.setdefault(key, []).append(kv)
    print("| scene | zoom | runs | " + " | ".join(COLS) + " |")
    print("|" + "---|" * (len(COLS) + 3))
    for (scene, zoom), runs in sorted(groups.items()):
        cells = []
        for c in COLS:
            vals = [float(r[c]) for r in runs if c in r]
            m = statistics.median(vals) if vals else float("nan")
            cells.append(f"{m:.0f}" if c in ("draw_calls", "draw_calls_max", "objects", "primitives", "ws_mb", "hitches", "startup_hitches") else f"{m:.1f}")
        print(f"| {scene} | {zoom} | {len(runs)} | " + " | ".join(cells) + " |")


if __name__ == "__main__":
    main()
