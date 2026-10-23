#!/usr/bin/env python3
"""Write game/data/rune_discovery.json: where runes are found (Brent 2026-10-23, design/14 section 8).

A discovered rune is permanent knowledge, usable in any seal. Runes are found through exploration and
combat. This script makes the data for each source; the rules that use it are Player.discover_rune and
friends (game/scripts/player.gd, "rune discovery").

- start: what a new character knows besides the base runes of its starting skills - per affinity, a
  couple of its runes (STARTING below: the affinity's first Cap and first Link in workbook order that
  no starter skill is built on, so a first seal can be closed).
- construct: subduing a Netherecho construct reveals a rune of its concept. Each concept is given a
  profile on the ten meaning axes of design/runes-data/rune-properties.json (CONCEPT_PROFILES below,
  hand-set [MODEL]); its runes are the nearest rune profiles (cosine), PER_AFFINITY per affinity so
  every character finds something it can use, plus the UNIVERSAL nearest universal runes. Universal
  runes come only from deeper tiers (BY_TIER).
- kills: a kill has a small chance to reveal a rune of the enemy's nature, picked the same way from a
  profile per enemy kind (KIND_PROFILES, [MODEL]).
- inscriptions: rune stones. Zone stones are in zones.json ("inscriptions" on a zone); the passage's
  are here (PASSAGE_INSCRIPTIONS), the deeper one universal.

Generated once from the profiles; re-run after the workbook or the profiles change:
    python -P -E tools/runes/rune_sources.py
Every number here is [MODEL]; Brent has not tuned any of them.
"""
import json
import math
from collections import OrderedDict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROPS = ROOT / "design/runes-data/rune-properties.json"
RUNES = ROOT / "game/data/runes.json"
ENEMIES = ROOT / "game/data/enemies.json"
CONSTRUCTS = ROOT / "game/data/constructs.json"
ABILITIES = ROOT / "game/data/abilities.json"
TREE = ROOT / "game/data/skill_tree.json"
OUT = ROOT / "game/data/rune_discovery.json"

AXES = ["heat", "motion", "force", "form", "vitality", "light", "mind", "extent", "duration", "binding", "direction"]
PER_AFFINITY = 3        # concept runes per affinity
UNIVERSAL = 3           # concept / kind universal runes
KIND_PER_AFFINITY = 2   # kill runes per affinity

# A concept as a point on the meaning axes (only the axes that matter; the rest are 0). [MODEL]
CONCEPT_PROFILES = {
    "acceleration": {"motion": 1.0, "force": 0.4, "duration": -0.6},
    "piercing": {"force": 0.8, "extent": -1.0, "binding": -0.5, "direction": 0.4},
    "compression": {"extent": -0.9, "direction": -0.7, "form": 0.5, "binding": 0.4},
    "tension": {"binding": 0.9, "force": 0.5, "motion": -0.3},
    "reach": {"extent": 0.9, "direction": 0.6, "motion": 0.3},
    "stillness": {"motion": -1.0, "duration": 0.6, "heat": -0.3},
}
# An enemy kind's nature. [MODEL]
KIND_PROFILES = {
    "grunt": {"force": 0.6, "form": 0.2, "mind": -0.6},
    "brute": {"force": 1.0, "form": 0.5, "mind": -0.8, "motion": -0.3},
    "commander": {"mind": 0.6, "binding": 0.6, "form": 0.6, "light": 0.2},
    "archer": {"extent": -0.8, "motion": 0.4, "direction": 0.7, "duration": -0.3},
    "harrier": {"motion": 1.0, "duration": -0.6, "force": 0.3},
    "pavise": {"form": 0.9, "binding": 0.6, "motion": -0.6, "direction": -0.3},
    "censer": {"vitality": -0.6, "extent": 0.7, "duration": 0.5, "light": -0.4},
    "drummer": {"duration": 0.6, "mind": 0.4, "force": 0.3, "direction": 0.5},
    # the Stubble's unstarred beasts (2026-10-23)
    "chaff_wren": {"motion": 0.9, "extent": 0.6, "vitality": 0.3, "duration": -0.5},
    "kettle_beetle": {"heat": 0.9, "form": 0.6, "force": 0.4, "duration": -0.4, "vitality": -0.2},
    "ditch_hound": {"motion": 0.7, "direction": 0.6, "vitality": 0.5, "mind": 0.2},
    "burr_hog": {"force": 1.0, "motion": 0.6, "form": 0.5, "direction": 0.7},
    "wirehorn": {"motion": 0.6, "light": 0.5, "extent": 0.4, "vitality": 0.4},
    "gleaner": {"motion": 0.7, "binding": 0.5, "mind": 0.4, "direction": -0.3},
    "sod_lurker": {"form": 0.7, "binding": 0.6, "motion": -0.6, "extent": -0.4, "vitality": 0.4},
    "thornback": {"vitality": 0.9, "form": 0.6, "force": 0.6, "duration": 0.5},
}
# A beast's themes (Brent 2026-10-23: nature-, earth- and water-themed creatures reveal fitting runes): a
# kill's pool holds THEMED_PER_AFFINITY runes for these affinities instead of KIND_PER_AFFINITY - more of
# what fits the creature, still picked by the creature's nature. [MODEL]
KIND_THEMES = {
    "chaff_wren": ["wind", "nature"],
    "kettle_beetle": ["fire", "water"],
    "ditch_hound": ["nature", "blood"],
    "burr_hog": ["earth", "nature"],
    "wirehorn": ["lightning", "nature"],
    "gleaner": ["wind", "death"],
    "sod_lurker": ["earth", "water"],
    "thornback": ["nature", "earth"],
}
THEMED_PER_AFFINITY = 4
# What a subdued construct reveals, by tier: how many runes, and the chance one of them is universal
# (universal runes come from deeper sources). [MODEL]
BY_TIER = OrderedDict([
    ("vestige", OrderedDict([("reveals", 1), ("universal_chance", 0.0)])),
    ("remnant", OrderedDict([("reveals", 1), ("universal_chance", 0.3)])),
    ("spirit", OrderedDict([("reveals", 2), ("universal_chance", 0.5)])),
    ("eidolon", OrderedDict([("reveals", 2), ("universal_chance", 0.7)])),
    ("asura", OrderedDict([("reveals", 3), ("universal_chance", 0.9)])),
])
KILLS = OrderedDict([
    ("chance", 0.04),                 # per kill, any kind not listed under chance_by_kind
    ("chance_by_kind", OrderedDict([("brute", 0.08), ("commander", 0.25), ("drummer", 0.08),
                                    # the Stubble's beasts: the common small ones seldom, the big ones more
                                    ("chaff_wren", 0.02), ("kettle_beetle", 0.04), ("ditch_hound", 0.04), ("gleaner", 0.05),
                                    ("burr_hog", 0.06), ("wirehorn", 0.06), ("sod_lurker", 0.07), ("thornback", 0.1)])),
    ("universal_chance", 0.1),        # of a kill's reveal, the share that is universal (rarer)
])
PASSAGE_INSCRIPTIONS = [
    OrderedDict([("id", "passage_wall_3"), ("chamber", 3), ("pool", "base"), ("name", "A scored wall-stone")]),
    OrderedDict([("id", "passage_wall_8"), ("chamber", 8), ("pool", "universal"), ("name", "A deep-cut wall-stone")]),
]
INSCRIPTION_RULES = OrderedDict([
    ("reach", 2.6),                   # metres from the stone at which it can be read
    ("base_fallback", True),          # a base stone whose runes you all know reveals any base rune you lack
])


def vec(p):
    return [float(p.get(a, 0.0)) for a in AXES]


def cos(a, b):
    na = math.sqrt(sum(x * x for x in a))
    nb = math.sqrt(sum(x * x for x in b))
    return 0.0 if na == 0 or nb == 0 else sum(x * y for x, y in zip(a, b)) / (na * nb)


def nearest(target, pool, n):
    scored = sorted(pool, key=lambda r: (-cos(target, vec(r["profile"])), r["id"]))
    return [r["id"] for r in scored[:n]]


def main():
    props = json.loads(PROPS.read_text(encoding="utf-8"))["runes"]
    runes = json.loads(RUNES.read_text(encoding="utf-8"))
    base = runes["base_runes"]
    uni = runes["universal_runes"]
    known = [r for r in props if r["id"] in base or r["id"] in uni]
    missing = [rid for rid in list(base) + list(uni) if rid not in {r["id"] for r in props}]
    if missing:
        raise SystemExit("rune_sources: no profile for %s - re-run tools/runes/rune_properties.py" % missing)
    affinities = list(runes["affinity_positions"].keys())
    by_aff = {a: [r for r in known if r["id"] in base and base[r["id"]]["affinity"] == a] for a in affinities}
    universal = [r for r in known if r["id"] in uni]

    concepts = json.loads(CONSTRUCTS.read_text(encoding="utf-8"))["concepts"]
    for c in concepts:
        if c not in CONCEPT_PROFILES:
            raise SystemExit("rune_sources: concept '%s' has no profile in CONCEPT_PROFILES" % c)
    kinds = json.loads(ENEMIES.read_text(encoding="utf-8"))["enemies"]
    for k in kinds:
        if k not in KIND_PROFILES:
            raise SystemExit("rune_sources: enemy kind '%s' has no profile in KIND_PROFILES" % k)

    def pools(profile, per_aff, n_uni, themes=()):
        t = vec(profile)
        out = OrderedDict([("base", OrderedDict([(a, nearest(t, by_aff[a], THEMED_PER_AFFINITY if a in themes else per_aff)) for a in affinities])),
                           ("universal", nearest(t, universal, n_uni))])
        if themes:
            out["themes"] = list(themes)
        return out

    # starting knowledge: per affinity, its first Cap and first Link (workbook order) that no starter
    # (root) skill is built on
    abilities = json.loads(ABILITIES.read_text(encoding="utf-8"))["abilities"]
    tree = json.loads(TREE.read_text(encoding="utf-8"))
    root_anchors = set()
    for aff_tree in tree["trees"].values():
        for aid, node in aff_tree.items():
            if int(node.get("tier", 0)) == 1 and aid in abilities:
                root_anchors.add(runes["skill_anchor"].get(aid, ""))
    start = OrderedDict()
    for a in affinities:
        picks = []
        for role in ("cap", "link"):
            for rid, r in base.items():
                if r["affinity"] == a and r["role"] == role and rid not in root_anchors and rid not in picks:
                    picks.append(rid)
                    break
        start[a] = picks

    out = OrderedDict([
        ("_note", "GENERATED by tools/runes/rune_sources.py - do not hand-edit; change the tables in the script and re-run. "
                  "Where runes are found (Brent 2026-10-23, design/14 section 8): a discovered rune is permanent knowledge. "
                  "start: runes a new character knows besides its starting skills' own runes. construct: subduing a construct "
                  "reveals runes of its concept ('reveals' per tier; a reveal is universal with 'universal_chance', which only "
                  "deeper tiers have) - the concept's runes are the nearest rune profiles (design/runes-data/rune-properties.json) "
                  "to a hand-set concept profile, per affinity, so any character finds runes it can use. kills: a kill reveals a rune "
                  "of the enemy kind's nature with 'chance'. inscriptions: rune stones; zone stones are listed on the zone in "
                  "zones.json, the passage's here by chamber. Only runes the character can use (its affinities' base runes, and "
                  "universal runes) and does not know yet are ever revealed. Every number is [MODEL]."),
        ("axes", AXES),
        ("start", OrderedDict([("affinity_runes", start)])),
        ("construct", OrderedDict([
            ("by_tier", BY_TIER),
            ("profiles", OrderedDict((c, CONCEPT_PROFILES[c]) for c in concepts)),
            ("concepts", OrderedDict((c, pools(CONCEPT_PROFILES[c], PER_AFFINITY, UNIVERSAL)) for c in concepts)),
        ])),
        ("kills", OrderedDict(list(KILLS.items()) + [
            ("profiles", OrderedDict((k, KIND_PROFILES[k]) for k in kinds)),
            ("by_kind", OrderedDict((k, pools(KIND_PROFILES[k], KIND_PER_AFFINITY, UNIVERSAL, KIND_THEMES.get(k, ()))) for k in kinds)),
        ])),
        ("inscriptions", OrderedDict(list(INSCRIPTION_RULES.items()) + [("passage", PASSAGE_INSCRIPTIONS)])),
    ])
    OUT.write_text(json.dumps(out, indent="\t", ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
    print("wrote %s: %d concepts, %d enemy kinds, start runes for %d affinities" % (OUT.relative_to(ROOT), len(concepts), len(kinds), len(start)))
    for c in concepts:
        print("  %-13s water %s  universal %s" % (c, [base[i]["name"] for i in out["construct"]["concepts"][c]["base"]["water"]],
                                                  [uni[i]["name"] for i in out["construct"]["concepts"][c]["universal"]]))
    print("  start water: %s" % [base[i]["name"] for i in start["water"]])


if __name__ == "__main__":
    main()
