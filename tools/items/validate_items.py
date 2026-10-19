#!/usr/bin/env python3
"""Check the full-game item catalogue draft (design/10-item-catalogue-v0.md). Stdlib only.

    python tools/items/validate_items.py [items.json] [recipes.json]

Defaults: design/data-drafts/items-full-v0.json and design/data-drafts/recipes-v0.json.
Exit code 0 = no errors (warnings are printed but do not fail), 1 = errors.

ERRORS: duplicate ids or names; missing or malformed fields; unknown slot; recipe inputs that do not exist,
recipe cycles, a recipes file that disagrees with the items; NaN, infinite or negative numbers (except the keys
that are meant to be negative); values that do not rise with band inside a category or along a line; a recipe
whose output sells for more than its inputs plus fee under the proposed sell rule; a name or description that
contains a name from the books (IP hygiene - CLAUDE.md rule 1).
WARNINGS: things that are fine for a draft but need a decision before the game loads it (live-rule arbitrage,
skills or techniques the game does not define yet, caps, crafting that costs more than buying).
"""
import json
import math
import statistics
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ITEMS_PATH = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "design/data-drafts/items-full-v0.json"
RECIPES_PATH = Path(sys.argv[2]) if len(sys.argv) > 2 else ROOT / "design/data-drafts/recipes-v0.json"

KNOWN_SLOTS = {"weapon", "offhand", "ranged", "head", "body", "hands", "feet", "back", "belt", "satellite", "trinket"}
KINDS = {"gear", "scroll", "manual", "spirit_imprint", "consumable", "ammo", "material", "reagent", "remains", "trade",
         "proof", "spoils", "catalyst", "key", "quest", "binding"}
RARITIES = {"salvage", "plain", "fine", "runed", "cursed", "unique"}
NO_PRICE = {"key", "quest"}                  # not sold; left out of the value-curve check
NEG_OK = {"max_health", "projection_hp_bonus", "crash_value", "ascension_quality", "step"}
LIVE_SELL = 0.5                               # game/data/items.json gear_sell_factor
# Names from the books and their world (research/ notes). None may appear in a name or description.
CANON_NAMES = [
    "Freddy", "Lissia", "Kaiya", "Umbra", "Morleppe", "Kraven", "Lawman", "Santorio", "Valhalla", "Basilisk",
    "Starhold", "Faralethal", "Nova York", "Northern Belt", "Overpearl", "Chaos Hammer", "Ocean Medallion",
    "Gem of Binding", "Inferior Gem", "Tsunami Strike", "Hydraulic Flex", "Hydraulic Throw", "Create Water",
    "Terror Knuckles", "Blood Javelin", "Absorb Blood", "Accelerate Blood", "Sanguine Avenger", "Knuckle Blade",
    "Floating Leaf", "Eagle Eyes", "Tectonic Strike", "Purifying Crimson", "Sea of Blood", "Crimson Mercury",
    "Water Body", "Wet Hells", "Abyssal Depths", "Perished Water", "Cycle Scythe", "Cycle Rose", "mirror rose",
    "Unholy Blessing", "Blood Ring", "Bloodshed Bond", "Blood Synergy", "Warrior King", "Soul-stabilizing",
    "Ether Capture", "Pale Moon", "Severe Clan", "Golden Sword", "Georgie League", "Silver Heart",
    "Twisted Pendulum", "Scorched Fleshmancer", "Frog Leap", "Flowing Strike", "Flowing River", "Flowing Rain",
    "Dissipate Wave", "Crimson Wing", "Crimson Twilight", "Crimson Dragon", "Chaotic Essence", "Wield Assist",
    "Weapon Empowerment", "Essence Extraction", "Rainbow Overlord",
]

errors, warnings = [], []


def err(msg):
    errors.append(msg)


def warn(msg):
    warnings.append(msg)


def no_dup_pairs(pairs):
    d = {}
    for k, v in pairs:
        if k in d:
            err(f"duplicate key '{k}'")
        d[k] = v
    return d


def load(path):
    try:
        return json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=no_dup_pairs)
    except (OSError, ValueError) as e:
        print(f"cannot read {path}: {e}")
        sys.exit(1)


data = load(ITEMS_PATH)
items = data.get("items", {})
recipes_file = load(RECIPES_PATH) if RECIPES_PATH.exists() else None
sell_rule = data.get("rules", {}).get("sell_factor_by_kind", {})


def sale_proposed(iid):
    it = items[iid]
    return it["value"] * float(sell_rule.get(it["kind"], 1.0))


def sale_live(iid):
    """What game/scripts/inventory.gd pays today: anything with a slot at half, everything else (but scrolls) in full."""
    it = items[iid]
    if it.get("slot", "") != "" or it.get("kind") == "scroll":
        return it["value"] * LIVE_SELL
    return float(it["value"])


# ---------- per-item checks ----------
names = defaultdict(list)
for iid, it in items.items():
    where = f"item '{iid}'"
    for f, t in (("name", str), ("slot", str), ("kind", str), ("category", str), ("desc", str)):
        if not isinstance(it.get(f), t):
            err(f"{where}: missing or bad '{f}'")
    for f in ("band", "stack", "value"):
        if not isinstance(it.get(f), int) or isinstance(it.get(f), bool):
            err(f"{where}: '{f}' must be an integer")
    if not isinstance(it.get("weight"), (int, float)):
        err(f"{where}: 'weight' must be a number")
    if not it.get("name") or not it.get("desc"):
        err(f"{where}: empty name or description")
    names[it.get("name", "")].append(iid)
    if isinstance(it.get("band"), int) and not 1 <= it["band"] <= 12:
        err(f"{where}: band {it['band']} outside 1-12")
    if isinstance(it.get("stack"), int) and it["stack"] < 1:
        err(f"{where}: stack below 1")
    if it.get("kind") not in KINDS:
        err(f"{where}: unknown kind '{it.get('kind')}'")
    slot = it.get("slot", "")
    if slot and slot not in KNOWN_SLOTS:
        err(f"{where}: unknown slot '{slot}'")
    if it.get("kind") == "gear":
        if not slot:
            err(f"{where}: gear with no slot")
        if it.get("rarity") not in RARITIES:
            err(f"{where}: gear rarity '{it.get('rarity')}' not one of {sorted(RARITIES)}")
    elif slot:
        err(f"{where}: kind '{it.get('kind')}' should not have a slot")
    if len(it.get("desc", "")) > 260:
        warn(f"{where}: description is {len(it['desc'])} characters")
    text = f"{it.get('name', '')} {it.get('desc', '')} {it.get('effect_text', '')}".lower()
    for n in CANON_NAMES:
        if n.lower() in text:
            err(f"{where}: contains the canon name '{n}'")
    st = it.get("stats", {})
    g = 1.05 ** (it.get("band", 1) - 1)  # the gear factor of design/10 section 4
    for k, v in st.items():
        if (k.startswith("cost_mult") and v < 0.75) or (k == "armour" and v > 13 * g) or (k == "wound_resist" and v > 16 * g):
            warn(f"{where}: {k} {v} is past the design/06 per-item range")
    if it.get("sellable") is False and it["value"] != 0:
        warn(f"{where}: not sellable but has a value")
for n, ids in names.items():
    if len(ids) > 1:
        err(f"name '{n}' used by {ids}")


# ---------- numbers ----------
def walk(path, v):
    if isinstance(v, bool):
        return
    if isinstance(v, (int, float)):
        if math.isnan(v) or math.isinf(v):
            err(f"{path}: not a finite number")
        elif v < 0 and path.rsplit(".", 1)[-1] not in NEG_OK:
            err(f"{path}: negative number {v}")
    elif isinstance(v, dict):
        for k, x in v.items():
            walk(f"{path}.{k}", x)
    elif isinstance(v, list):
        for i, x in enumerate(v):
            walk(f"{path}[{i}]", x)


for iid, it in items.items():
    walk(iid, it)

# ---------- recipes ----------
for iid, it in items.items():
    r = it.get("recipe")
    if not r:
        continue
    where = f"recipe of '{iid}'"
    for f in ("station", "grade", "stars", "inputs", "fee", "makes", "hours"):
        if f not in r:
            err(f"{where}: missing '{f}'")
    if recipes_file and r.get("station") not in recipes_file.get("stations", {}):
        err(f"{where}: unknown station '{r.get('station')}'")
    if not r.get("inputs"):
        err(f"{where}: no inputs")
    for inp, n in r.get("inputs", {}).items():
        if inp not in items:
            err(f"{where}: input '{inp}' does not exist")
        if not isinstance(n, int) or n < 1:
            err(f"{where}: input count {n} for '{inp}'")
    if iid in r.get("inputs", {}):
        err(f"{where}: uses itself")
    if not (isinstance(r.get("makes"), int) and r["makes"] >= 1):
        err(f"{where}: makes must be a positive integer")
    if isinstance(r.get("stars"), int) and not 1 <= r["stars"] <= 12:
        err(f"{where}: stars {r['stars']}")
    if any(inp not in items for inp in r.get("inputs", {})):
        continue
    cost_sale = sum(sale_proposed(k) * n for k, n in r["inputs"].items()) + r["fee"]
    out_sale = sale_proposed(iid) * r["makes"]
    if out_sale > cost_sale * 1.01 + 1:
        err(f"{where}: sells for {out_sale:.0f}, inputs + fee only {cost_sale:.0f} (money from nothing)")
    live_cost = sum(sale_live(k) * n for k, n in r["inputs"].items()) + r["fee"]
    if sale_live(iid) * r["makes"] > live_cost * 1.01 + 1:
        warn(f"LIVE-RULE ARBITRAGE {where}: under today's sell rule it sells for {sale_live(iid) * r['makes']:.0f} against {live_cost:.0f}")
    buy_cost = sum(items[k]["value"] * n for k, n in r["inputs"].items()) + r["fee"]
    if it["kind"] == "gear" and buy_cost > it["value"] * r["makes"] * 1.01:
        warn(f"{where}: making it ({buy_cost:.0f}) costs more than buying it ({it['value'] * r['makes']})")
# cycles
graph = {iid: list(it.get("recipe", {}).get("inputs", {}).keys()) for iid, it in items.items()}
state = {}


def visit(n, stack):
    state[n] = 1
    for m in graph.get(n, []):
        if state.get(m) == 1:
            err(f"recipe cycle: {' -> '.join(stack + [n, m])}")
        elif m in graph and not state.get(m):
            visit(m, stack + [n])
    state[n] = 2


for n in graph:
    if not state.get(n):
        visit(n, [])
# the recipes view must match the items
if recipes_file:
    seen = set()
    for r in recipes_file.get("recipes", []):
        out = r.get("output")
        seen.add(out)
        if out not in items or "recipe" not in items[out]:
            err(f"recipes file: '{r.get('id')}' makes '{out}', which has no recipe in the items")
            continue
        mine = items[out]["recipe"]
        for f in ("station", "grade", "stars", "inputs", "fee", "makes", "hours"):
            if r.get(f) != mine.get(f):
                err(f"recipes file: '{r.get('id')}' field '{f}' disagrees with the item")
    missing = [i for i, it in items.items() if "recipe" in it and i not in seen]
    if missing:
        err(f"recipes file is missing {len(missing)} recipes, e.g. {missing[:3]}")

# ---------- value curves ----------
by_cat_band = defaultdict(lambda: defaultdict(list))
by_line = defaultdict(list)
for iid, it in items.items():
    by_cat_band[it["category"]][it["band"]].append(it["value"])
    if "line" in it:
        by_line[it["line"]].append((it["band"], it["value"], iid))
for cat, bands in sorted(by_cat_band.items()):
    if cat in NO_PRICE:
        continue
    prev = None
    for b in sorted(bands):
        med = statistics.median(bands[b])
        if prev is not None and med <= prev[1]:
            err(f"category '{cat}': median value at band {b} ({med:,.0f}) is not above band {prev[0]} ({prev[1]:,.0f})")
        prev = (b, med)
for line, rows in sorted(by_line.items()):
    rows.sort()
    for (b1, v1, i1), (b2, v2, i2) in zip(rows, rows[1:]):
        if b2 == b1:
            continue
        if v2 <= v1:
            err(f"line '{line}': {i2} (band {b2}, {v2:,}) is not worth more than {i1} (band {b1}, {v1:,})")

# ---------- things the game does not define yet ----------
try:
    abilities = json.loads((ROOT / "game/data/abilities.json").read_text(encoding="utf-8"))["abilities"]
    temper = json.loads((ROOT / "game/data/tempering.json").read_text(encoding="utf-8"))["techniques"]
    pieces = json.loads((ROOT / "game/data/wardrobe.json").read_text(encoding="utf-8"))["pieces"]
except (OSError, ValueError, KeyError):
    abilities, temper, pieces = None, None, None
if abilities is not None:
    for iid, it in items.items():
        if it.get("teaches") and it["teaches"] not in abilities:
            err(f"item '{iid}': teaches '{it['teaches']}', which abilities.json does not define")
        if it.get("teaches_technique") and it["teaches_technique"] not in temper:
            warn(f"item '{iid}': technique '{it['teaches_technique']}' is in design/05 but not yet in tempering.json")
        if "look" in it and it["look"] not in pieces:
            err(f"item '{iid}': look '{it['look']}' is not a wardrobe.json piece")

# ---------- every id the game or design/06 already uses is kept (so saves and drafts still resolve) ----------
for ref, key in ((ROOT / "game/data/items.json", "items"), (ROOT / "design/data-drafts/items-v2.json", "items")):
    try:
        ids = json.loads(ref.read_text(encoding="utf-8"))[key]
    except (OSError, ValueError, KeyError):
        warn(f"could not read {ref.name} to check its ids are kept")
        continue
    missing = [i for i in ids if i not in items]
    if missing:
        err(f"{len(missing)} ids of {ref.name} are missing, e.g. {missing[:5]}")

# ---------- summary ----------
cats = sorted(by_cat_band)
bands = sorted({it["band"] for it in items.values()})
w = max(len(c) for c in cats + ["category"]) + 1
print(f"Item catalogue draft: {ITEMS_PATH.relative_to(ROOT) if ITEMS_PATH.is_relative_to(ROOT) else ITEMS_PATH}")
print(f"{len(items)} items, {sum(1 for it in items.values() if 'recipe' in it)} recipes, "
      f"{sum(1 for it in items.values() if it.get('kind') == 'gear')} pieces of gear\n")
print("Counts per category per band")
print("category".ljust(w) + "".join(f"{b:>5}" for b in bands) + "  total")
for c in cats:
    row = [len(by_cat_band[c].get(b, [])) for b in bands]
    print(c.ljust(w) + "".join(f"{(n if n else '.'):>5}" for n in row) + f"  {sum(row):>5}")
tot = [sum(len(by_cat_band[c].get(b, [])) for c in cats) for b in bands]
print("ALL".ljust(w) + "".join(f"{n:>5}" for n in tot) + f"  {sum(tot):>5}")
print("\nValue per band (dollars; keys and quest items left out)")
print(f"{'band':>4} {'items':>6} {'min':>16} {'median':>16} {'max':>18}")
for b in bands:
    vals = [it["value"] for it in items.values() if it["band"] == b and it["category"] not in NO_PRICE]
    print(f"{b:>4} {len(vals):>6} {min(vals):>16,} {statistics.median(vals):>16,.0f} {max(vals):>18,}")
rar = defaultdict(int)
for it in items.values():
    if it.get("kind") == "gear":
        rar[it["rarity"]] += 1
print("\nGear by rarity: " + ", ".join(f"{r} {rar[r]}" for r in ("salvage", "plain", "fine", "runed", "cursed", "unique")))
live_arb = [x for x in warnings if x.startswith("LIVE-RULE")]
other = [x for x in warnings if not x.startswith("LIVE-RULE")]
print(f"\nWarnings: {len(warnings)} ({len(live_arb)} recipes would make money under today's sell rule - see design/10 section 12)")
for x in other[:40]:
    print("  WARN " + x)
if len(other) > 40:
    print(f"  ... and {len(other) - 40} more")
for x in live_arb[:3]:
    print("  WARN " + x)
print(f"Errors: {len(errors)}")
for x in errors[:60]:
    print("  ERROR " + x)
if len(errors) > 60:
    print(f"  ... and {len(errors) - 60} more")
print("RESULT: " + ("PASS" if not errors else "FAIL"))
sys.exit(1 if errors else 0)
