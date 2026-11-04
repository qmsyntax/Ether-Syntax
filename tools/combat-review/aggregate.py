"""Aggregate probe results by (scenario, tier, tag) -> means. python -I aggregate.py file1.jsonl [file2...]"""
import json, sys
from collections import defaultdict
rows = []
for fn in sys.argv[1:]:
    rows += [json.loads(l) for l in open(fn, encoding="utf-8") if l.strip()]
rows = [r for r in rows if "failed" not in r]
groups = defaultdict(list)
for r in rows:
    groups[(r["scenario"], r["tier"], r["tag"])].append(r)
def m(rs, f):
    v = [f(r) for r in rs]
    return sum(v) / max(1, len(v))
print("| scenario | tier | policy (tag) | runs | died | survived s (mean) | fight % | walk % | meditate % | rest+loot % | kills / min | kills / fight-min | casts / fight-min | strikes / fight-min | skill share of damage | fight time too dry to cast | casts that touched nothing | HP lost / fight-min | in-fight healing / run | enemies within 10 m (mean, max) | fight length s |")
print("|" + "---|" * 21)
for (sc, tier, tag), rs in sorted(groups.items()):
    g = lambda r: max(0.001, r["game_s"])
    print("| %s | %s | %s | %d | %d | %.0f | %.0f%% | %.0f%% | %.0f%% | %.0f%% | %.1f | %.1f | %.1f | %.0f | %.0f%% | %.0f%% | %.0f%% | %.0f | %.0f | %.1f (%d) | %.1f |" % (
        sc, tier, tag, len(rs), sum(r["deaths"] for r in rs), m(rs, lambda r: r["game_s"]),
        100 * m(rs, lambda r: r["fight_s"] / g(r)), 100 * m(rs, lambda r: r["walk_s"] / g(r)), 100 * m(rs, lambda r: r["meditate_s"] / g(r)),
        100 * m(rs, lambda r: (r["rest_s"] + r["loot_s"]) / g(r)),
        m(rs, lambda r: r["kills_per_min"]), m(rs, lambda r: r["kills_per_fight_min"]), m(rs, lambda r: r["casts_per_fight_min"]),
        m(rs, lambda r: r["strikes_per_fight_min"]), 100 * m(rs, lambda r: r["dmg_share_skill"]), 100 * m(rs, lambda r: r["dry_frac"]),
        100 * m(rs, lambda r: r["whiff_frac"]), m(rs, lambda r: r["taken_per_fight_min"]), m(rs, lambda r: r["healed_in_fight"]),
        m(rs, lambda r: r["engaged_avg"]), max(r["engaged_max"] for r in rs), m(rs, lambda r: r["fight_len_avg"])))
# engaged histogram (time share), by scenario+tier
print()
print("Engaged-enemy histogram (share of fight time with N enemies within 10 m):")
for (sc, tier, tag), rs in sorted(groups.items()):
    h = defaultdict(float)
    for r in rs:
        for k, v in r["engaged_hist"].items():
            h[int(k)] += v / len(rs)
    print(f"  {sc:8} {tier:4} {tag:16} " + "  ".join(f"{k}:{100*h[k]:.0f}%" for k in sorted(h)))
print()
print("Rewards per minute of play:")
for (sc, tier, tag), rs in sorted(groups.items()):
    print("  %-8s %-4s %-16s aura/min %.1f  star%%/min %.3f  skill-progress/min %.1f  remains value picked/min %.0f  kills/min %.1f" % (sc, tier, tag,
        m(rs, lambda r: r["aura_gained"] / (r["game_s"] / 60)), m(rs, lambda r: r["star_pct_gained"] / (r["game_s"] / 60)),
        m(rs, lambda r: r["skill_progress_gained"] / (r["game_s"] / 60)), m(rs, lambda r: r["loot_value_picked"] / (r["game_s"] / 60)), m(rs, lambda r: r["kills_per_min"])))
print()
print("TTK (first hit -> death), seconds, by tier and scenario:")
pool = defaultdict(list)
for r in rows:
    for k, (s, n) in r["ttk_by"].items():
        pool[(r["scenario"] if r["scenario"] != "passage" else "arena+passage", r["tier"], k)].append((s, n))
for key in sorted(pool):
    v = pool[key]; n = sum(x[1] for x in v); s = sum(x[0] * x[1] for x in v) / max(1, n)
    print(f"  {key[0]:14} {key[1]:4} {key[2]:14} {s:5.1f} s  (n={n})")
