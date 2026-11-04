"""Before -> after table for the combat-review probe (2026-11-03 review, section 7 targets).
python -I compare.py before.jsonl after.jsonl [more.jsonl ...] [--abilities=game/data/abilities.json]
Each file is one column set; rows are (scenario, tier). The measures are the ones the review set targets for:
casts per fight-minute, skill share of damage, fight time too dry to cast, reflux-lock refusals (share of presses),
meditation (share of game time), melee bursts that touched nothing, Slingstone hit rate, health lost per fight-minute,
deaths."""
import json, sys, os
from collections import defaultdict

args = [a for a in sys.argv[1:] if not a.startswith("--")]
opts = dict(a[2:].split("=", 1) for a in sys.argv[1:] if a.startswith("--") and "=" in a)
here = os.path.dirname(os.path.abspath(__file__))
ab_path = opts.get("abilities", os.path.join(here, "..", "..", "game", "data", "abilities.json"))
abilities = json.load(open(ab_path, encoding="utf-8"))
abilities = abilities.get("abilities", abilities)
kind_of = {k: (v.get("kind") if isinstance(v, dict) else None) for k, v in abilities.items()}


def load(fn):
    rows = [json.loads(l) for l in open(fn, encoding="utf-8") if l.strip()]
    return [r for r in rows if "failed" not in r]


def measures(rs):
    out = {}
    n = len(rs)
    fight = sum(r["fight_s"] for r in rs)
    game = sum(r["game_s"] for r in rs)
    casts = sum(r["casts"] for r in rs)
    out["runs"] = n
    out["casts / fight-min"] = sum(r["casts_per_fight_min"] for r in rs) / max(1, n)
    out["skill share"] = 100 * sum(r["dmg_share_skill"] for r in rs) / max(1, n)
    out["dry %"] = 100 * sum(r["dry_frac"] for r in rs) / max(1, n)
    presses = sum(r["presses"] for r in rs)
    lock = sum(v for r in rs for k, v in r.get("refusal_lines", {}).items() if "locked by reflux" in k)
    out["reflux-lock refusals % of presses"] = 100 * lock / max(1, presses)
    out["meditate % of time"] = 100 * sum(r["meditate_s"] / max(0.001, r["game_s"]) for r in rs) / max(1, n)
    bc = bh = 0
    sc = sh = 0
    for r in rs:
        for k, v in r["casts_by"].items():
            if kind_of.get(k) == "melee_burst":
                bc += v
                bh += r["casts_hit"].get(k, 0)
            if k == "slingstone":
                sc += v
                sh += r["casts_hit"].get(k, 0)
    out["melee bursts touching nothing %"] = (100 * (bc - bh) / bc) if bc else None
    out["melee burst casts"] = bc
    out["Slingstone hit %"] = (100 * sh / sc) if sc else None
    out["Slingstone casts"] = sc
    out["HP lost / fight-min"] = sum(r["taken_per_fight_min"] for r in rs) / max(1, n)
    out["deaths"] = sum(r["deaths"] for r in rs)
    out["survived s"] = sum(r["game_s"] for r in rs) / max(1, n)
    return out


cols = [(os.path.basename(f), load(f)) for f in args]
groups = sorted({(r["scenario"], r["tier"], r.get("tag", "")) for _, rows in cols for r in rows})
keys = ["runs", "casts / fight-min", "skill share", "dry %", "reflux-lock refusals % of presses", "meditate % of time",
        "melee bursts touching nothing %", "melee burst casts", "Slingstone hit %", "Slingstone casts", "HP lost / fight-min",
        "deaths", "survived s"]


def fmt(v):
    if v is None:
        return "-"
    if isinstance(v, int):
        return str(v)
    return "%.0f" % v if abs(v) >= 10 else "%.1f" % v


for g in groups:
    print("\n### %s, %s character, policy %s\n" % g)
    print("| measure | " + " | ".join(name for name, _ in cols) + " |")
    print("|---|" + "---|" * len(cols))
    per = [measures([r for r in rows if (r["scenario"], r["tier"], r.get("tag", "")) == g]) for _, rows in cols]
    for k in keys:
        print("| %s | %s |" % (k, " | ".join(fmt(m.get(k)) if m.get("runs") else "-" for m in per)))
