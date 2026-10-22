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
# game/scripts/runes/interactions/) are listed by id per rule set.
ACTIVE_RULE_SET = "bond_v1"

# Shown on the rune-setting screen under the word: what is not decided yet.
BOND_V1_NOTES = [
    "A locked word changes its skill; an unlocked one does nothing yet.",
    "Not decided yet: bond strength, unstable words, flaws, reactions between runes.",
    "Universal runes have placeholder bonds (2) until Brent sets them.",
]

# Rune effects, layers 1-3 (Brent 2026-10-22; constants on Bond Rules rows 19-40). These are the
# parts the workbook does not hold as numbers. The interaction script is
# game/scripts/runes/interactions/effects_v1.gd.
EFFECTS_V1 = OrderedDict([
    # Bond Rules A40: "a quarter of the change as power instead" - the quarter as a number
    ("fallback_fraction", 0.25),
    # [MODEL] a grant (a status, a shove, a mark...) the skill cannot use counts as this much change
    # before the quarter is taken: so an unusable grant at full strength is +5% power
    ("grant_as_change", 0.2),
    # [MODEL] where the fallback goes: power, or - for a skill that deals no damage - cost (a power
    # gain becomes a cost cut of the same size)
    ("fallback_groups", ["power", "cost"]),
    # groups where a smaller number is the better one (their fallback and their colour flip)
    ("lower_is_better", ["cost", "reflux", "windup"]),
    # stat group -> ability fields (abilities.json). "a.b" is a nested field; "field@kind|kind" only
    # counts for skills of those kinds. Built from what abilities.json really has (2026-10-22).
    ("stat_groups", OrderedDict([
        ("power", ["damage", "damage_mult", "on_hit.damage", "on_rise.damage", "relay_hit.damage", "zone.payload.damage",
                   "per_stack_damage", "bonus_damage", "pip_damage", "per_stack_burst", "damage_from_heat", "retaliate"]),
        ("reach", ["range", "life@projectile", "reach_bonus", "range_bonus", "radius", "burst_radius", "arc_deg", "width@beam|prop",
                   "jump_radius", "pass_radius", "relay_radius", "relay_range", "arrive_radius", "through_dist",
                   "zone.radius", "zone.length", "zone.width", "trail.width"]),
        ("speed", ["speed", "dash_speed"]),
        ("cost", ["cost"]),
        ("reflux", ["reflux_per_cost"]),
        ("windup", ["windup", "recovery", "delay", "rise_time"]),
        ("duration", ["duration", "life@prop|rod", "zone.life", "trail.life", "leave_prop.life"]),
        ("poise", ["on_hit.poise", "heavy_poise", "on_stop.poise", "zone.payload.poise"]),
    ])),
    # where a grant goes: the first of these hit payloads the skill has
    ("payload_parts", ["on_hit", "on_arrive", "on_pass", "on_stop", "on_rise", "relay_hit", "zone.payload", "trail.payload"]),
    # a field that is a full turn can grow no further
    ("field_caps", OrderedDict([("arc_deg", 360)])),
    # the skill's stage multiplies these when it is cast (Player.ability_damage_mult), so the preview does too
    ("stage_scaled_groups", ["power"]),
    # units for the effects preview
    ("group_units", OrderedDict([("windup", " s"), ("duration", " s")])),
    ("field_units", OrderedDict([("arc_deg", " deg"), ("life", " s"), ("range", " m"), ("radius", " m"), ("reach_bonus", " m"),
                                 ("range_bonus", " m"), ("burst_radius", " m"), ("jump_radius", " m"), ("zone.radius", " m"),
                                 ("zone.length", " m"), ("zone.width", " m"), ("width", " m")])),
    # words for the effects preview
    ("group_words", OrderedDict([("power", "damage"), ("reach", "range and area"), ("speed", "speed"), ("cost", "essence cost"),
                                 ("reflux", "reflux"), ("windup", "wind-up"), ("duration", "duration"), ("poise", "poise damage")])),
    ("field_labels", OrderedDict([
        ("damage", "Damage"), ("damage_mult", "Damage (x a strike)"), ("on_hit.damage", "Damage"), ("on_rise.damage", "Damage as it rises"),
        ("relay_hit.damage", "Relay damage"), ("zone.payload.damage", "Damage per tick"), ("per_stack_damage", "Damage per stack"),
        ("bonus_damage", "Bonus damage"), ("pip_damage", "Damage per pip"), ("per_stack_burst", "Burst per stack"),
        ("damage_from_heat", "Damage per heat"), ("retaliate", "Retaliation damage"),
        ("range", "Range"), ("life@projectile", "Flight time"), ("reach_bonus", "Reach"), ("range_bonus", "Reach"), ("radius", "Radius"),
        ("burst_radius", "Burst radius"), ("arc_deg", "Arc"), ("width@beam|prop", "Width"), ("jump_radius", "Jump radius"),
        ("pass_radius", "Sweep radius"), ("relay_radius", "Relay radius"), ("relay_range", "Relay range"), ("arrive_radius", "Arrival radius"),
        ("through_dist", "Carries through"), ("zone.radius", "Zone radius"), ("zone.length", "Zone length"), ("zone.width", "Zone width"),
        ("trail.width", "Trail width"), ("speed", "Speed"), ("dash_speed", "Dash speed"), ("cost", "Essence cost"),
        ("reflux_per_cost", "Reflux per essence"), ("windup", "Wind-up"), ("recovery", "Recovery"), ("delay", "Delay"),
        ("rise_time", "Rise time"), ("duration", "Duration"), ("life@prop|rod", "Stands for"), ("zone.life", "Zone lasts"),
        ("trail.life", "Trail lasts"), ("leave_prop.life", "Stone stands for"), ("on_hit.poise", "Poise damage"),
        ("heavy_poise", "Poise damage (heavy)"), ("on_stop.poise", "Poise damage"), ("zone.payload.poise", "Poise damage per tick"),
    ])),
])

EFFECT_GROUPS = list(EFFECTS_V1["stat_groups"].keys())
STATUSES = ROOT / "game/data/statuses.json"


def parse_effect(text_in, rid, statuses):
    """One op per ';' (Bond Rules A40). Returns a list of ops; exits on anything it cannot read."""
    ops = []
    for part in [p.strip() for p in str(text_in or "").split(";") if p.strip()]:
        m = re.fullmatch(r"(\w+) x([\d.]+)", part)
        if m and m.group(1) in EFFECT_GROUPS:
            ops.append(OrderedDict([("op", "mul"), ("group", m.group(1)), ("value", clean(float(m.group(2))))]))
            continue
        m = re.fullmatch(r"status (\w+)(?: (\d+))?", part)
        if m:
            if m.group(1) not in statuses:
                sys.exit("export_runes_json: %s grants status '%s', which statuses.json does not have" % (rid, m.group(1)))
            ops.append(OrderedDict([("op", "status"), ("id", m.group(1)), ("stacks", int(m.group(2) or 1))]))
            continue
        m = re.fullmatch(r"(shove|pull|marks|jumps|pierce) \+([\d.]+)", part)
        if m:
            ops.append(OrderedDict([("op", m.group(1)), ("value", clean(float(m.group(2))))]))
            continue
        if part in ("interrupts", "braced"):
            ops.append(OrderedDict([("op", part)]))
            continue
        m = re.fullmatch(r"bonus (\w+) \+([\d.]+)", part)
        if m:
            if m.group(1) not in statuses:
                sys.exit("export_runes_json: %s has a bonus against '%s', which statuses.json does not have" % (rid, m.group(1)))
            ops.append(OrderedDict([("op", "bonus"), ("status", m.group(1)), ("value", clean(float(m.group(2))))]))
            continue
        sys.exit("export_runes_json: %s effect '%s' is not in the effect syntax (Bond Rules A40)" % (rid, part))
    return ops


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
    cells = {(r, c): v for r, row in enumerate(br.iter_rows(min_row=1, max_row=42, values_only=True), 1) for c, v in enumerate(row, 1)}
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

    # --- rune effects, layers 1-3 (Bond Rules rows 19-40) ---------------------------------------
    if not text(cells.get((22, 1))).lower().startswith("bonds from the skill"):
        sys.exit("export_runes_json: Bond Rules A22 is not the strength-by-bonds header - the layout moved")
    fade = []
    for r in range(23, 27):
        bonds = text(cells.get((r, 1)))
        fade.append(OrderedDict([("bonds", int(re.match(r"\d+", bonds).group(0))), ("or_more", "more" in bonds),
                                 ("strength", clean(num(cells.get((r, 2)), "Bond Rules B%d" % r)))]))
    kind_factors = OrderedDict()
    for r in range(29, 32):
        kind_factors[text(cells.get((r, 1))).lower()] = OrderedDict([("more_pull", clean(num(cells.get((r, 2)), "Bond Rules B%d" % r))),
                                                                     ("less_pull", clean(num(cells.get((r, 3)), "Bond Rules C%d" % r)))])
    if list(kind_factors) != ["even", "polar", "ionic"]:
        sys.exit("export_runes_json: Bond Rules A29:A31 are not Even, Polar, Ionic - the layout moved")
    labels = {33: "a status applies", 34: "lowest multiplier", 35: "highest multiplier", 36: "a word must be closed"}
    for r, start in labels.items():
        if not text(cells.get((r, 1))).lower().startswith(start):
            sys.exit("export_runes_json: Bond Rules A%d is not '%s...' - the layout moved" % (r, start))
    status_threshold = clean(num(cells.get((33, 2)), "Bond Rules B33"))
    mult_min = clean(num(cells.get((34, 2)), "Bond Rules B34"))
    mult_max = clean(num(cells.get((35, 2)), "Bond Rules B35"))
    lock_needs_closed = bool(num(cells.get((36, 2)), "Bond Rules B36"))
    anchor_rule_text = text(cells.get((38, 1)))
    syntax_text = text(cells.get((40, 1)))
    statuses = set(json.loads(STATUSES.read_text(encoding="utf-8"))["statuses"].keys())

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
        effect = text(row[14]) if len(row) > 14 else ""
        if effect:
            base[rid]["effect"] = effect
            base[rid]["ops"] = parse_effect(effect, rid, statuses)

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
        effect = text(row[7]) if len(row) > 7 else ""
        if effect:
            universal[rid]["effect"] = effect
            universal[rid]["ops"] = parse_effect(effect, rid, statuses)

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
                  "has not set them. Rune effects (layers 1-3, Bond Rules rows 19-40): each rune's 'effect' text and parsed 'ops', worked out by "
                  "the interaction effects_v1 (scripts/runes/interactions/effects_v1.gd) from bond_v1.interaction_params.effects_v1; "
                  "they change a skill only while its word is locked."),
        ("rule_set", ACTIVE_RULE_SET),
        ("rule_sets", OrderedDict([
            ("bond_v1", OrderedDict([
                ("script", "res://scripts/runes/bond_rules.gd"),
                ("title", "Bonds (first rules, 2026-10-22)"),
                ("refuse_below", refuse_below), ("weaken_below", weaken_below),
                ("electronegativity_centre", en_centre), ("roles", roles), ("bond_kinds", bond_kinds),
            ] + list(WORD_RULES.items()) + [
                ("lock_needs_closed", lock_needs_closed),
                ("interactions", ["effects_v1"]),
                ("interaction_params", OrderedDict([
                    ("effects_v1", OrderedDict([
                        ("fade", fade), ("kind_factors", kind_factors), ("status_threshold", status_threshold),
                        ("mult_min", mult_min), ("mult_max", mult_max),
                    ] + list(EFFECTS_V1.items()) + [
                        ("anchor_rule", anchor_rule_text), ("syntax", syntax_text),
                    ])),
                ])),
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
