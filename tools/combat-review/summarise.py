"""Summarise results.jsonl from the combat-review probe into markdown tables.
python -I summarise.py results.jsonl"""
import json, sys
from collections import defaultdict

rows = [json.loads(l) for l in open(sys.argv[1], encoding="utf-8") if l.strip()]
rows = [r for r in rows if "failed" not in r]


def f(x, n=1):
    return f"{x:.{n}f}" if isinstance(x, (int, float)) else str(x)


print("| run | aff | skills | end | game s | fight % | walk % | med % | kills/min | casts/fight-min | strikes/fight-min | skill dmg share | dry % | whiff % | taken/fight-min | engaged avg (max) | deaths |")
print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
for r in rows:
    g = max(0.001, r["game_s"])
    print("| %s %s %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s (%s) | %s |" % (
        r["scenario"], r["tier"], ("med" if r["meditate"] == "1" else "nomed") + ("/dash" if r["dodge"] == "dash" else ""),
        r["aff"], "+".join(r["skills"]), r["end"], f(r["game_s"], 0), f(100 * r["fight_s"] / g, 0), f(100 * r["walk_s"] / g, 0),
        f(100 * r["meditate_s"] / g, 0), f(r["kills_per_min"], 2), f(r["casts_per_fight_min"]), f(r["strikes_per_fight_min"]),
        f(100 * r["dmg_share_skill"], 0), f(100 * r["dry_frac"], 0), f(100 * r["whiff_frac"], 0), f(r["taken_per_fight_min"]),
        f(r["engaged_avg"], 2), r["engaged_max"], r["deaths"]))

print()
print("TTK by kind (seconds, n) pooled over runs, by tier:")
pool = defaultdict(list)
for r in rows:
    for k, (s, n) in r["ttk_by"].items():
        pool[(r["tier"], k)].append((s, n))
for (tier, k), v in sorted(pool.items()):
    n = sum(x[1] for x in v)
    s = sum(x[0] * x[1] for x in v) / max(1, n)
    print(f"  {tier:4} {k:14} {s:5.1f} s  n={n}")

print()
print("Press outcomes pooled:")
po = defaultdict(int)
for r in rows:
    for k, v in r["press_outcomes"].items():
        po[k] += v
tot = sum(po.values())
for k, v in sorted(po.items(), key=lambda x: -x[1]):
    print(f"  {k:30} {v:6}  {100*v/max(1,tot):.0f}%")
print()
print("Refusal lines pooled:")
rl = defaultdict(int)
for r in rows:
    for k, v in r.get("refusal_lines", {}).items():
        rl[k] += v
for k, v in sorted(rl.items(), key=lambda x: -x[1]):
    print(f"  {v:5}  {k}")
print()
print("Per-skill casts / casts that touched an enemy:")
cb = defaultdict(int); hb = defaultdict(int); db = defaultdict(float)
for r in rows:
    for k, v in r["casts_by"].items():
        cb[k] += v
    for k, v in r["casts_hit"].items():
        hb[k] += v
    for k, v in r["dmg_by_skill"].items():
        db[k] += v
for k in sorted(cb, key=lambda x: -cb[x]):
    print(f"  {k:20} casts {cb[k]:5}  hit {hb[k]:5} ({100*hb[k]/max(1,cb[k]):.0f}%)  dmg/cast {db[k]/max(1,cb[k]):6.0f}")
print()
print("Damage by source pooled (by tier):")
ds = defaultdict(lambda: defaultdict(float))
for r in rows:
    for k, v in r["dmg_by_src"].items():
        ds[r["tier"]][k] += v
for tier, d in ds.items():
    t = sum(d.values())
    print("  " + tier + ": " + ", ".join(f"{k} {100*v/max(1,t):.0f}%" for k, v in d.items()))
print()
print("Reward:")
for r in rows:
    g = max(0.001, r["game_s"]) / 60
    print(f"  {r['scenario']:8} {r['tier']:4} {r['aff']:6} kills {r['kills']:3} loot picked {r['loot_value_picked']:6} left {r['loot_value_left']:6} per-min {r['loot_per_min']:6}  aura {r['aura_gained']:7}  star% {r['star_pct_gained']:7}  skillprog {r['skill_progress_gained']:7}  wounds {r['wounds']}  healed-in-fight {r['healed_in_fight']}  hits taken {r['hits_taken']}  fight len {r['fight_len_avg']}")
