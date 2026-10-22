#!/usr/bin/env python3
"""Export game/data/runes.json from design/runes-workbook.xlsx (design/14 section 7).

The workbook is Brent's and the source of truth for runes. This script only READS it, with
openpyxl data_only=True, so it gets the values Excel last computed and saved. It never writes to
the workbook. Edit the workbook (in Excel, and save it there so the cached values update), then
re-run:

    python tools/runes/export_runes_json.py

What it writes:
- base_runes: every row of "Base Runes" (id, affinity, name, character, opposite, role, valence,
  electronegativity, meaning = "As a skill"), plus "as_means" where the affinity sheet has one;
- universal_runes: every row of "Universal Runes" (meaning = "As a means"). Brent has not given
  them a role, valence or electronegativity yet, so they carry PLACEHOLDER values (below) and
  "placeholder": true;
- axes and affinity_positions: "Slider Links" columns G-K (-1..+1 per axis);
- rule_set / rule_sets: which rule set is in force (ACTIVE_RULE_SET) and each rule set's script and
  params. bond_v1's params are the alignment thresholds ("Alignment" B19/B20), the role table,
  electronegativity centre and bond-kind thresholds ("Bond Rules"), and the word rules from Brent's
  2026-10-22 rulings (WORD_RULES below - these are not in the workbook). A new rule set gets an
  entry here and a script in game/scripts/runes/;
- skill_anchor: ability id (game/data/abilities.json) -> the base rune it is built on, from the
  affinity sheets' "Skills on it" names matched exactly to abilities' display names. Nothing is
  guessed: names that do not match are listed under "unmatched" and printed.
"""
import json
import re
import sys
from collections import OrderedDict
from pathlib import Path

import openpyxl

ROOT = Path(__file__).resolve().parents[2]
WORKBOOK = ROOT / "design/runes-workbook.xlsx"
ABILITIES = ROOT / "game/data/abilities.json"
OUT = ROOT / "game/data/runes.json"

# Universal runes have no role yet (Brent has not set them). Until he does they are Links at the
# electronegativity centre: two bonds, and an even bond with a middling rune. [MODEL placeholder]
UNIVERSAL_PLACEHOLDER = {"valence": 2, "electronegativity": 2.5}

# Brent 2026-10-22 (design/14 section 7 and the rune-setting brief). Not in the workbook.
WORD_RULES = OrderedDict([
    # level 0 holds 4 runes, level 1 holds 6: +2 per level [B]
    ("capacity_base", 4),
    ("capacity_per_level", 2),
    # OPEN [B 2026-10-22]: whether the skill's own base rune counts in the 4. Default: it does.
    ("anchor_counts", True),
    # not ruled [MODEL]: the same rune may appear more than once in a word (as atoms repeat in a
    # molecule); set false to forbid it
    ("allow_repeats", True),
    # not ruled [MODEL]: a closed word must also be one piece, every rune joined to the anchor
    ("closed_needs_connected", True),
])

# Which rule set the game uses. A rule set is a GDScript extending RuneRules; its entry under
# "rule_sets" names the script and carries its params. Interactions (RuneInteraction scripts in
# game/scripts/runes/interactions/) are listed by id per rule set; none exist yet.
ACTIVE_RULE_SET = "bond_v1"

# Shown on the rune-setting screen under the word: what is not decided yet.
BOND_V1_NOTES = [
    "Runes do not change a skill's numbers yet.",
    "Not decided yet: bond strength, unstable words, flaws, reactions.",
    "Universal runes have placeholder bonds (2) until Brent sets them.",
]


def text(v):
    return "" if v is None else str(v).strip()


def num(v, what):
    if v is None or v == "":
        sys.exit("export_runes_json: %s is empty in the workbook (open it in Excel and save, so values are cached)" % what)
    return float(v)


def clean(x):
    """Round away float noise from Excel (2.6199999999 -> 2.62); keep ints as ints."""
    x = round(float(x), 4)
    return int(x) if x == int(x) else x


def main():
    wb = openpyxl.load_workbook(WORKBOOK, data_only=True, read_only=True)

    # --- bond rules ---------------------------------------------------------------------
    br = wb["Bond Rules"]
    cells = {(r, c): v for r, row in enumerate(br.iter_rows(min_row=1, max_row=20, values_only=True), 1) for c, v in enumerate(row, 1)}
    roles = OrderedDict()
    for r in range(4, 8):
        role = text(cells.get((r, 1)))
        roles[role.lower()] = OrderedDict([("valence", int(num(cells.get((r, 2)), "Bond Rules B%d" % r))),
                                           ("spread", clean(num(cells.get((r, 3)), "Bond Rules C%d" % r)))])
    if text(cells.get((9, 1))).lower() != "electronegativity centre":
        sys.exit("export_runes_json: Bond Rules A9 is not 'Electronegativity centre' - the layout moved")
    en_centre = clean(num(cells.get((9, 2)), "Bond Rules B9"))
    bond_kinds = []
    for r in range(13, 16):
        bond_kinds.append(OrderedDict([("kind", text(cells.get((r, 1))).lower()), ("from", clean(num(cells.get((r, 2)), "Bond Rules B%d" % r)))]))
    if [k["kind"] for k in bond_kinds] != ["even", "polar", "ionic"]:
        sys.exit("export_runes_json: Bond Rules A13:A15 are not Even, Polar, Ionic - the layout moved")

    # --- alignment thresholds -------------------------------------------------------------
    al = wb["Alignment"]
    al_cells = {(r, c): v for r, row in enumerate(al.iter_rows(min_row=1, max_row=22, max_col=2, values_only=True), 1) for c, v in enumerate(row, 1)}
    if not text(al_cells.get((19, 1))).lower().startswith("refuse") or not text(al_cells.get((20, 1))).lower().startswith("weaken"):
        sys.exit("export_runes_json: Alignment A19/A20 are not the refuse / weaken thresholds - the layout moved")
    refuse_below = clean(num(al_cells.get((19, 2)), "Alignment B19"))
    weaken_below = clean(num(al_cells.get((20, 2)), "Alignment B20"))

    # --- affinity positions -----------------------------------------------------------------
    sl = wb["Slider Links"]
    rows = list(sl.iter_rows(min_row=1, max_row=17, values_only=True))
    axes = []
    for h in rows[0][6:11]:
        axes.append(re.sub(r"\s*\(.*\)", "", text(h)).lower().replace("/", "_").replace(" ", "_"))
    positions = OrderedDict()
    for row in rows[1:]:
        if text(row[0]):
            positions[text(row[0]).lower()] = [clean(num(v, "Slider Links %s" % text(row[0]))) for v in row[6:11]]

    # --- base runes ---------------------------------------------------------------------------
    base = OrderedDict()
    for row in wb["Base Runes"].iter_rows(min_row=2, values_only=True):
        rid = text(row[0])
        if not rid:
            continue
        role = text(row[10]).lower()
        if role not in roles:
            sys.exit("export_runes_json: %s has role '%s', not one of %s" % (rid, row[10], list(roles)))
        valence = int(num(row[12], "%s valence" % rid))
        if valence != roles[role]["valence"]:
            sys.exit("export_runes_json: %s valence %d does not match its role %s" % (rid, valence, role))
        base[rid] = OrderedDict([
            ("id", rid), ("affinity", text(row[1]).lower()), ("name", text(row[3])), ("character", text(row[4])),
            ("opposite", text(row[5])), ("role", role), ("valence", valence),
            ("electronegativity", clean(num(row[13], "%s electronegativity" % rid))), ("meaning", text(row[8])),
        ])

    # --- universal runes ------------------------------------------------------------------------
    universal = OrderedDict()
    for row in wb["Universal Runes"].iter_rows(min_row=2, values_only=True):
        rid = text(row[0])
        if not rid:
            continue
        universal[rid] = OrderedDict([
            ("id", rid), ("name", text(row[1])), ("character", text(row[2])), ("opposite", text(row[3])),
            ("valence", UNIVERSAL_PLACEHOLDER["valence"]), ("electronegativity", UNIVERSAL_PLACEHOLDER["electronegativity"]),
            ("placeholder", True), ("meaning", text(row[6])),
        ])

    # --- affinity sheets: as-means text and the skills on each rune ----------------------------------
    abilities = json.loads(ABILITIES.read_text(encoding="utf-8"))["abilities"]
    by_name = {}
    for aid, a in abilities.items():
        by_name.setdefault(a["name"], []).append(aid)
    anchor = OrderedDict()
    unmatched_names = []      # "Skills on it" names with no ability of that name and affinity
    conflicts = []
    for aff in positions:
        sheet = aff.capitalize()
        if sheet not in wb.sheetnames:
            continue
        for row in wb[sheet].iter_rows(min_row=6, values_only=True):
            rid = text(row[1])
            if rid not in base:
                continue
            if text(row[5]):
                base[rid]["as_means"] = text(row[5])
            for raw in text(row[8]).split(","):
                name = re.sub(r"\s*\(.*?\)", "", raw).strip()
                if not name:
                    continue
                ids = [i for i in by_name.get(name, []) if abilities[i].get("affinity") == base[rid]["affinity"]]
                if len(ids) != 1:
                    unmatched_names.append("%s (%s, %s)" % (name, rid, base[rid]["name"]))
                    continue
                if ids[0] in anchor and anchor[ids[0]] != rid:
                    conflicts.append("%s on both %s and %s" % (ids[0], anchor[ids[0]], rid))
                    continue
                anchor[ids[0]] = rid
    no_rune = [aid for aid in abilities if aid not in anchor]
    # abilities.json order, so the map reads like the ability list
    anchor = OrderedDict((aid, anchor[aid]) for aid in abilities if aid in anchor)

    out = OrderedDict([
        ("_note", "GENERATED by tools/runes/export_runes_json.py from design/runes-workbook.xlsx - do not hand-edit. "
                  "Edit the workbook (and save it in Excel so its values are cached), or WORD_RULES in the script, and re-run. "
                  "Rune words: design/14 section 7 (Brent 2026-10-22). A skill is built on one base rune (skill_anchor); "
                  "runes are added and linked. A saved word is rule-free (nodes + links, scripts/runes/rune_word.gd); "
                  "'rule_set' picks the rules in force from 'rule_sets' (each names a script extending RuneRules, plus its params). "
                  "bond_v1 (scripts/runes/bond_rules.gd): single bonds; each rune makes at most its valence in bonds; a word is closed "
                  "when every rune's bonds equal its valence. The electronegativity difference sets a bond's kind (bond_kinds, "
                  "'from' = smallest difference). Two base runes of different affinities bond only if the cosine of their "
                  "affinity_positions is at least refuse_below; below weaken_below the bond is weakened. Universal "
                  "runes have no position. Universal valence and electronegativity are PLACEHOLDERS (placeholder: true): Brent "
                  "has not set them. Runes do not change any skill's numbers yet."),
        ("rule_set", ACTIVE_RULE_SET),
        ("rule_sets", OrderedDict([
            ("bond_v1", OrderedDict([
                ("script", "res://scripts/runes/bond_rules.gd"),
                ("title", "Bonds (first rules, 2026-10-22)"),
                ("refuse_below", refuse_below), ("weaken_below", weaken_below),
                ("electronegativity_centre", en_centre), ("roles", roles), ("bond_kinds", bond_kinds),
            ] + list(WORD_RULES.items()) + [
                ("interactions", []),
                ("notes", BOND_V1_NOTES),
            ])),
        ])),
        ("axes", axes),
        ("affinity_positions", positions),
        ("base_runes", base),
        ("universal_runes", universal),
        ("skill_anchor", anchor),
        ("unmatched", OrderedDict([("sheet_skills_without_ability", unmatched_names), ("abilities_without_rune", no_rune),
                                   ("conflicts", conflicts)])),
    ])
    OUT.write_text(json.dumps(out, indent="\t", ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
    print("wrote %s: %d base runes, %d universal runes, %d affinities, %d skills anchored" % (
        OUT.relative_to(ROOT), len(base), len(universal), len(positions), len(anchor)))
    for n in unmatched_names:
        print("  unmatched sheet skill: " + n)
    for a in no_rune:
        print("  ability with no rune: " + a)
    for c in conflicts:
        print("  conflict: " + c)


if __name__ == "__main__":
    main()
