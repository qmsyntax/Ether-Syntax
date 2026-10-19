#!/usr/bin/env python3
"""Emit game/data/crafting.json - crafting step 1 (design/12) - from the crafting drafts.

The drafts stay the source of truth: design/data-drafts/items-full-v0.json and recipes-v0.json
(built by build_items_draft.py from crafting_tables.py). This takes only what step 1 needs:

- the band-1 recipes of Rendering, Leatherwork and Smithing that are Plain or subcombines (no
  pattern book), whose output is a live item (game/data/items.json) or a material or a tool of one
  of those three skills, and whose every input can be had: a live item (remains drop from kills),
  something a craftsperson sells (VENDOR below), or the output / byproduct of another included recipe;
- the items those recipes make or need that are not live yet (materials, byproducts, tools, the
  Flensing Kit), copied from the draft with an icon from ICON_BY_LINE;
- the three stations, the tools' kinds, the skills, and the rules as numbers (CRAFT_NUMBERS).

Live item ids are never redefined here: GameData adds these items only where items.json has no
entry. Re-run after the drafts change:  python tools/items/emit_crafting_game.py
"""
import json
from collections import OrderedDict
from pathlib import Path

from crafting_tables import CRAFT_NUMBERS

ROOT = Path(__file__).resolve().parents[2]
ITEMS_DRAFT = ROOT / "design/data-drafts/items-full-v0.json"
RECIPES_DRAFT = ROOT / "design/data-drafts/recipes-v0.json"
LIVE_ITEMS = ROOT / "game/data/items.json"
OUT = ROOT / "game/data/crafting.json"

SKILLS = ["rendering", "leatherwork", "smithing"]
BAND = 1

# What each craftsperson sells (design/11: the guild vendors sell band-1 basics and tier-1 tools).
# Crucible, fitting mould, tanning liquor and haft are made by Pottery, Brewing and Bowyery, which
# are not built yet: they are sold here as a stopgap until those skills arrive [MODEL].
VENDOR = OrderedDict([
    ("flensing_yard", ["flensing_knife", "flensing_kit"]),
    ("leatherworks", ["curriers_knife", "heartwood_tanning_liquor"]),
    ("forge", ["smiths_hammer", "scrap_iron", "flux_salt", "barrow_crucible", "barrow_fitting_mould", "heartwood_haft"]),
])
# What a craftsperson charges to teach the trade: every included recipe of their skill [MODEL].
TEACH_PRICE = {"rendering": 50, "leatherwork": 75, "smithing": 100}
# Inventory glyphs (scripts/ui/ui_draw.gd) by draft line; the default is "crate".
ICON_BY_LINE = {
    "mat_scraped": "hide", "mat_leather": "hide", "mat_tallow": "ash", "mat_marrow": "seed", "mat_meal": "ash",
    "mat_quench": "drop", "mat_liquor": "drop", "mat_bar": "salvage", "mat_sheet": "plate", "mat_wire": "cord",
    "mat_rivets": "salvage", "mat_fittings": "salvage", "mat_alloy": "plate", "mat_mould_fitting": "chest", "mat_ore": "salvage",
    "mat_salt": "ash", "mat_crucible": "chest", "mat_mould": "chest", "mat_haft": "stave", "mat_grip": "cord",
    "mat_strap": "belt", "kit_flensing_yard": "chest",
}
ICON_BY_KIND = {"tool": "blade"}
ITEM_KEYS = ["name", "slot", "kind", "category", "band", "weight", "value", "desc", "tool", "kit"]
RECIPE_KEYS = ["id", "output", "makes", "skill", "trivial", "min_skill", "tool", "station", "grade", "inputs", "fee", "hours", "byproducts"]


def main() -> None:
    items = json.loads(ITEMS_DRAFT.read_text(encoding="utf-8"))["items"]
    drafts = json.loads(RECIPES_DRAFT.read_text(encoding="utf-8"))
    live = json.loads(LIVE_ITEMS.read_text(encoding="utf-8"))["items"]

    def wanted_output(r: dict) -> bool:
        out = items.get(r["output"], {})
        if r["output"] in live:
            return True
        if out.get("kind") == "material":
            return True
        return out.get("kind") == "tool" and (out.get("tool") or {}).get("skill") in SKILLS

    pool = [r for r in drafts["recipes"] if r.get("skill") in SKILLS and r.get("band") == BAND
            and not r.get("pattern") and wanted_output(r)]
    have = set(live) | {i for stock in VENDOR.values() for i in stock}
    chosen: list = []
    grew = True
    while grew:
        grew = False
        for r in pool:
            if r in chosen or not all(i in have for i in r["inputs"]):
                continue
            chosen.append(r)
            have.add(r["output"])
            have.update((r.get("byproducts") or {}).keys())
            grew = True
    chosen.sort(key=lambda r: (SKILLS.index(r["skill"]), r["trivial"], r["id"]))

    needed = set()
    for r in chosen:
        needed.add(r["output"])
        needed.update(r["inputs"])
        needed.update((r.get("byproducts") or {}).keys())
    for stock in VENDOR.values():
        needed.update(stock)
    new_items = OrderedDict()
    for iid in sorted(needed):
        if iid in live:
            continue
        src = items[iid]
        d = OrderedDict((k, src[k]) for k in ITEM_KEYS if k in src)
        d["icon"] = ICON_BY_LINE.get(src.get("line", ""), ICON_BY_KIND.get(src.get("kind", ""), "crate"))
        new_items[iid] = d

    stations = OrderedDict()
    for sid in VENDOR:
        st = drafts["stations"][sid]
        skill = next(s for s in SKILLS if sid in drafts["skills"][s]["stations"])
        stations[sid] = OrderedDict([("name", st["name"]), ("skill", skill), ("grade", 1), ("what", st.get("what", "")),
                                     ("sells", VENDOR[sid])])
    tools = OrderedDict()
    for s in SKILLS:
        kind = drafts["skills"][s]["tool"]
        tools[kind] = OrderedDict([("name", drafts["tools"][kind]["name"]), ("skill", s)])
    skills = OrderedDict()
    for s in SKILLS:
        sk = drafts["skills"][s]
        skills[s] = OrderedDict([("name", sk["name"]), ("tool", sk["tool"]), ("makes", sk.get("makes", "")),
                                 ("teach_price", TEACH_PRICE[s])])

    out = OrderedDict([
        ("_note", "GENERATED by tools/items/emit_crafting_game.py from design/data-drafts (do not hand-edit; edit the "
                  "tables and re-run). Crafting step 1 (design/12): band-1 Rendering, Leatherwork and Smithing. rules: "
                  "design/11 section 4 as numbers (tools/items/crafting_tables.py CRAFT_NUMBERS); no cap by stars "
                  "(Brent 2026-10-18). stations: grade, skill and what the craftsperson there sells. recipes: trivial, "
                  "min_skill (the attempt window), tool {kind, tier}, fee (paid to the station), makes, byproducts, hours "
                  "(no world clock yet - see design/12). items: only items items.json does not have; GameData adds them "
                  "and never overrides a live id. Every number is a first guess [MODEL]."),
        ("rules", CRAFT_NUMBERS),
        ("skills", skills),
        ("tools", tools),
        ("stations", stations),
        ("recipes", OrderedDict((r["id"], OrderedDict((k, r[k]) for k in RECIPE_KEYS if k in r and k != "id")) for r in chosen)),
        ("items", new_items),
    ])
    OUT.write_text(json.dumps(out, indent="\t", ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
    by_skill = {s: sum(1 for r in chosen if r["skill"] == s) for s in SKILLS}
    print("wrote %s: %d recipes %s, %d new items" % (OUT.relative_to(ROOT), len(chosen), by_skill, len(new_items)))
    for r in chosen:
        print("  %-12s %-28s trivial %3d  %s" % (r["skill"], r["output"], r["trivial"], dict(r["inputs"])))


if __name__ == "__main__":
    main()
