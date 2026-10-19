#!/usr/bin/env python3
"""Build the full-game item catalogue DRAFT (design/10-item-catalogue-v0.md).

Writes design/data-drafts/items-full-v0.json and design/data-drafts/recipes-v0.json.
Nothing here is loaded by the game. Stdlib only.

How the draft is made
- Band 1 (one star) is the approved design/06 catalogue (design/data-drafts/items-v2.json), merged
  with the live ids in game/data/items.json (live names, descriptions and values win, except the two
  design/06 retunes Brent approved on 2026-10-12: river_stone and cooling_coil).
- Bands 2-12 are built from "lines": a band-1 exemplar item scaled by the band factors in BANDS
  (G = gear, W = weight, V = value, B = body, S = strike), named after that band's material, with a
  recipe from that band's refined materials. Hand-written cursed and unique items sit on top.
- Every name and description is original to this project [MODEL]. Nothing is taken from the books.

Re-run after editing a table:  python tools/items/build_items_draft.py
Then check:                    python tools/items/validate_items.py
Hand edits to the JSON are lost on a re-run; edit the tables here instead.
"""
import json
import math
from collections import OrderedDict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
V2_PATH = ROOT / "design/data-drafts/items-v2.json"
LIVE_PATH = ROOT / "game/data/items.json"
OUT_ITEMS = ROOT / "design/data-drafts/items-full-v0.json"
OUT_RECIPES = ROOT / "design/data-drafts/recipes-v0.json"

AFFS = ["water", "fire", "earth", "wind", "lightning"]
AFF_LABEL = {"water": "Water", "fire": "Fire", "earth": "Earth", "wind": "Wind", "lightning": "Lightning"}
AFF_WORD = {"water": "Tide", "fire": "Ember", "earth": "Loam", "wind": "Gale", "lightning": "Storm"}
AFF_STONE = {"water": "Brinepearl", "fire": "Emberite", "earth": "Loamstone", "wind": "Galequill", "lightning": "Fulgurite"}

# --------------------------------------------------------------------------------------------
# Band factors [MODEL]. One band = one star. 11 and 12 are "10 stars and beyond".
# --------------------------------------------------------------------------------------------
BAND_MAX = 12
RULES = {
    "gear_factor_per_band": 1.05,      # G: main numbers of gear
    "value_factor_per_band": 4.0,      # V: every price and sell value
    "body_health_per_star": 1.3,       # B: the body's health (balance.json ascension_2.body_scale)
    "body_strike_per_star": 1.25,      # S: the body's strike and shot damage (proposal)
    "worn_free_kg": 14.0,              # design/06 2.1
    "worn_per_star_kg": 8.0,
}


def G(b):
    return RULES["gear_factor_per_band"] ** (b - 1)


def V(b):
    return RULES["value_factor_per_band"] ** (b - 1)


def B(b):
    return RULES["body_health_per_star"] ** (b - 1)


def S(b):
    return RULES["body_strike_per_star"] ** (b - 1)


def W(b):
    """Weight factor: the square root of how much more the body may wear at that star."""
    free, per = RULES["worn_free_kg"], RULES["worn_per_star_kg"]
    return math.sqrt((free + per * (b - 1)) / free)


def grade(b):
    """Station grade a band needs."""
    return min(6, math.ceil(b / 2))


def nice(x):
    if x <= 0:
        return 0
    if x < 100:
        return max(1, int(round(x)))
    p = 10 ** (int(math.floor(math.log10(x))) - 1)
    return int(round(x / p) * p)


def kg(x):
    if x >= 10:
        return round(x * 2) / 2
    return max(0.1, round(x, 1))


def r3(x):
    return round(x, 3)


def trip(b):
    """Reference income of one ordinary trip out at band b, in dollars [MODEL]."""
    return 5000 * V(b)


# --------------------------------------------------------------------------------------------
# The ladder: per band, the materials and what lives there. All names ours [MODEL].
# --------------------------------------------------------------------------------------------
BAND_INFO = {
    1: dict(label="1 star", where="The Barrow Marches (design/07 region 1)", construct="vestige",
            word="Sealed", metal="Iron", leather="Cured Hide", wood="Heartwood", cloth="Linen",
            grade_word="Flecked"),
    2: dict(label="2 stars", where="The Sallow Fen and the Hackle (design/07 regions 2-3)", construct="remnant",
            word="Iron-Bound", metal="Gatesteel", leather="Reedback", wood="Bog-Oak", cloth="Fen-Silk"),
    3: dict(label="3 stars", where="The Rimeward and the first Understeps (design/07 regions 4-5)",
            construct="remnant to spirit", word="Steeped", metal="Steeped Steel", leather="Whiteback",
            wood="Rimepine", cloth="Rime-Floss", grade_word="Clouded"),
    4: dict(label="4 stars", where="The deep Understeps (not designed)", construct="spirit",
            word="Warded", metal="Wardsilver", leather="Stalker-Hide", wood="Tawny Ash", cloth="Moth-Silk"),
    5: dict(label="5 stars", where="Realms past the Understeps (not designed)", construct="spirit to eidolon",
            word="Veined", metal="Veiniron", leather="Drakeskin", wood="Veinwood", cloth="Lantern-Silk",
            grade_word="Clear"),
    6: dict(label="6 stars", where="Sunless realms (not designed)", construct="eidolon",
            word="Dusk", metal="Duskmetal", leather="Gloamhide", wood="Gloamwood", cloth="Pale Fleece"),
    7: dict(label="7 stars", where="Quiet realms (not designed)", construct="eidolon to asura [?]",
            word="Still", metal="Stillsteel", leather="Wyrmhide", wood="Stillwood", cloth="Still-Silk",
            grade_word="Bright"),
    8: dict(label="8 stars", where="Realms that lie in both planes (not designed)", construct="asura [?]",
            word="Echoing", metal="Echo-Iron", leather="Twinhide", wood="Echo-Ash", cloth="Echo-Floss"),
    9: dict(label="9 stars", where="Giant realms (not designed)", construct="beyond asura [?]",
            word="Heart-Sealed", metal="Heartmetal", leather="Gianthide", wood="Crownroot", cloth="Heartsilk",
            grade_word="Singing"),
    10: dict(label="10 stars", where="The first realms (not designed)", construct="beyond asura [?]",
             word="First-Struck", metal="Firstmetal", leather="Coilhide", wood="Firstwood", cloth="Dawn-Floss"),
    11: dict(label="10 stars and beyond (11)", where="Unwritten (not designed)", construct="unknown [?]",
             word="Unwritten", metal="Unwritten Alloy", leather="Unwritten Hide", wood="Unwritten Wood",
             cloth="Unwritten Cloth", grade_word="Unblemished"),
    12: dict(label="10 stars and beyond (12)", where="Unmade (not designed)", construct="unknown [?]",
             word="Unmade", metal="Unmade Metal", leather="Unmade Hide", wood="Unmade Wood", cloth="Unmade Cloth"),
}
SETTLED_GRADES = [1, 3, 5, 7, 9, 11]   # bands where a new grade of settled ether appears


def settled_grade(b):
    return max(g for g in SETTLED_GRADES if g <= b)


MAT_CLAUSE = {
    "metal": {
        2: "Gatesteel is passage scrap, smelted honestly.",
        3: "Steeped steel sat a season in rich ether and came out changed.",
        4: "Wardsilver holds a rune without ink, if it likes you.",
        5: "Veiniron is dug, not smelted: it grows through realm rock like a root.",
        6: "Duskmetal drinks the light along its edges.",
        7: "Stillsteel does not ring when struck. Nothing about it wants to move.",
        8: "Echo-iron casts a shadow in the Netherecho as well as here.",
        9: "Heartmetal comes from the middle of realms that were holding on to it.",
        10: "Firstmetal is what the other metals were trying to be.",
        11: "Unwritten alloy has no maker's mark, because no maker has a word for it.",
        12: "Unmade metal is not sure it exists. It hits as if it does.",
    },
    "leather": {
        2: "Reedback hide from the fen, oiled against the wet.",
        3: "Whiteback pelt, shaved and boiled; it still smells of snow.",
        4: "Stalker-hide keeps the colour of the grass for a week after it is cut.",
        5: "Drakeskin: scale on the outside, patience on the inside.",
        6: "Gloamhide stays cool in any weather.",
        7: "Wyrmhide was cut from something that lived under a mountain.",
        8: "Twinhide: the other half of the beast is still in the Netherecho.",
        9: "Gianthide, a hand thick. One beast dresses a company.",
        10: "Coilhide, from a serpent longer than a street.",
        11: "Unwritten hide from a beast with no name in any catalogue.",
        12: "Unmade hide. Whatever wore it first was never born.",
    },
    "wood": {
        2: "Bog-oak, black from a century under the fen.",
        3: "Rimepine, straight and light, cut where it never thaws.",
        4: "Tawny ash from the grass realm, where trees are rare and argued over.",
        5: "Veinwood grows on realm rock and drinks what is in it.",
        6: "Gloamwood bends like a thought and comes back.",
        7: "Stillwood does not warp, crack or forgive.",
        8: "Echo-ash is the same tree in two places at once.",
        9: "Crownroot: the root of a tree nobody has seen the top of.",
        10: "Firstwood remembers being the first tree.",
        11: "Unwritten wood: no grain, no rings, no age.",
        12: "Unmade wood. It was never a tree, and it still floats.",
    },
    "cloth": {
        2: "Fen-silk from the spinners in the reeds; it sheds water and heat.",
        3: "Rime-floss is warm and lighter than it has any right to be.",
        4: "Moth-silk from the Spindle, unspooled one careful thread at a time.",
        5: "Lantern-silk glows faintly when your reflux runs high.",
        6: "Pale fleece, from beasts that graze in the dark.",
        7: "Still-silk makes no sound, moving or not.",
        8: "Echo-floss is woven in two places; only one of them is here.",
        9: "Heartsilk: each thread is a long breath, held.",
        10: "Dawn-floss, from moths that fly only at a realm's first light.",
        11: "Unwritten cloth takes the colour of whoever looks at it.",
        12: "Unmade cloth has no weave to fray.",
    },
}

# Remains per band: role -> (id suffix, name, band-1 reference kg, band-1 reference $, desc).
# A = hide (tanned into the band's leather), B = bone/horn/fang (masterwork for wood, leather, cloth),
# C = fibre (spun into the band's cloth), M = parts of a made thing (masterwork for metal work), E = an elite's trophy.
REMAINS_REF = {"A": (8.0, 500), "B": (2.0, 250), "C": (1.0, 200), "M": (3.0, 300), "E": (2.0, 1500)}
BESTIARY = {
    2: {"A": ("reedback_hide", "Reedback Hide", "From a slow fen grazer with a back like a thatched roof. Tanners in Pilings pay well."),
        "B": ("ridge_ram_horn", "Ridge Ram Horn", "A spiral of horn off a ram that butts climbers off the Hackle's ledges."),
        "C": ("spinner_silk_skein", "Spinner Silk Skein", "Wound off a reed spinner's web before it could wake. Sticky for a day."),
        "M": ("effigy_ironwork", "Toll-Effigy Ironwork", "The iron bones of a made thing that stood at a crossing and demanded payment."),
        "E": ("reeve_chain", "Fen Reeve's Chain", "A chain of office off a fen reeve. Someone in Pilings will want it back.")},
    3: {"A": ("whiteback_pelt", "Whiteback Pelt", "A snow bear's pelt, heavy as a wet sail. Worth the walk if you can make it."),
        "B": ("glass_elk_antler", "Glass Elk Antler", "Clear as ice and nearly as cold. Carvers and alchemists both bid."),
        "C": ("rime_floss_tuft", "Rime Floss Tuft", "The winter down of something that nests in drifts. Weighs nothing."),
        "M": ("warden_rivets", "Cairn Warden Rivets", "Rivets out of a stone guardian's joints. The stone stayed; the metal came."),
        "E": ("marshal_brand", "Gate Marshal's Brand", "A branding iron carried by the thing that held the gate. Still warm.")},
    4: {"A": ("stalker_hide", "Tawny Stalker Hide", "From a grass-coloured hunter that is mostly shoulders. Tanners pay by the span."),
        "B": ("step_hound_fang", "Step-Hound Fang", "A fang from a hound that follows you from one step to the next."),
        "C": ("moth_cocoon", "Spindle Moth Cocoon", "A cocoon as long as a forearm. Unwind it slowly or not at all."),
        "M": ("sentinel_clockwork", "Sentinel Clockwork", "Gears from a tower's sentinel. Some still turn when nobody is looking."),
        "E": ("collector_seal", "Collector's Seal", "The seal of a thing that collected on debts in a vault. Collectors collect it.")},
    5: {"A": ("vein_drake_hide", "Vein Drake Hide", "A drake that swims through rock. Its scales are mostly rock."),
        "B": ("borer_tooth", "Borer Tooth", "One tooth out of a worm's ring of hundreds. It still bites into metal."),
        "C": ("lantern_weaver_silk", "Lantern Weaver Silk", "Silk from a spider that hangs lights to fish with. It glows when warm."),
        "M": ("sexton_bellmetal", "Sexton Bell-Metal", "A made caretaker's bell, cracked. It rang for every death in its halls."),
        "E": ("drake_matron_crest", "Drake Matron's Crest", "The crest-plate of a matron drake. Nobody in town will believe you without it.")},
    6: {"A": ("gloam_stag_hide", "Gloam Stag Hide", "A stag that grazes where there has never been a sun. The hide is cool to touch."),
        "B": ("duskwing_bone", "Duskwing Bone", "A hollow wing-bone. It whistles in no wind at all."),
        "C": ("pale_fleece", "Pale Shearling Fleece", "Sheared off a dark-grazing beast that does not mind. Sold by the bale."),
        "M": ("mirror_plate", "Mirror Knight Plate", "A plate off a made knight that fought with your own face. It reflects badly."),
        "E": ("lamplighter_lantern", "Lamplighter's Lantern", "The only light in a dark realm, taken off what carried it. It is out now.")},
    7: {"A": ("mantle_wyrm_hide", "Mantle Wyrm Hide", "From under a mountain. It takes two people to roll and one fool to carry."),
        "B": ("hush_cat_claw", "Hush Cat Claw", "A claw from a cat that makes no sound. Neither does the claw, dropped."),
        "C": ("still_spider_silk", "Still Spider Silk", "Silk that does not sway. Bowyers would kill for it, and some have."),
        "M": ("colossus_joint", "Quiet Colossus Joint", "A knee from a giant made thing that never made a sound. Heavy."),
        "E": ("choir_bell", "Choir Mother's Bell", "The bell from the thing that sang the others to sleep. Do not ring it.")},
    8: {"A": ("twinned_elk_hide", "Twinned Elk Hide", "An elk that stands in both planes. Only half its hide came with you."),
        "B": ("echo_hound_fang", "Echo Hound Fang", "It bites twice: once here, once in the Netherecho."),
        "C": ("echo_moth_floss", "Echo Moth Floss", "Floss from a moth that is in two places. Weigh it twice."),
        "M": ("engine_escapement", "Echo Engine Escapement", "The heart of a made engine that ran in both planes. It ticks out of step."),
        "E": ("counterpart_mask", "Counterpart's Mask", "The mask of a thing that copied whoever fought it. Yours, for a while.")},
    9: {"A": ("crag_giant_hide", "Crag Giant Hide", "A strip of hide off a giant-class thing. A strip is what one person carries."),
        "B": ("sky_ray_spine", "Sky Ray Spine", "A tail spine off a ray that swims in the air. Still venomous."),
        "C": ("heartsilk_cocoon", "Heartsilk Cocoon", "A cocoon that beats slowly in the hand. Spin it before it stops."),
        "M": ("warden_heartplate", "Throne Warden Heartplate", "The chest-plate of a made warden that guarded an empty throne."),
        "E": ("matriarch_torc", "Crag Matriarch's Torc", "A neck-ring a giant wore. You could wear it as a belt.")},
    10: {"A": ("deepcoil_hide", "Deepcoil Serpent Hide", "From a serpent longer than a street. You cut the length you can carry."),
         "B": ("firstbone", "Firstbone", "A bone from the first beast of its kind, which was also the last."),
         "C": ("dawn_moth_floss", "Dawn Moth Floss", "Gathered at a realm's first light, before the moths knew to hide it."),
         "M": ("unsleeping_cog", "Unsleeping Cog", "A cog from an engine that has run since before people. It is still trying."),
         "E": ("tithe_taker_scale", "Tithe-Taker's Scale", "The scale of the thing that weighed everything that passed it.")},
    11: {"A": ("unwritten_beast_hide", "Unwritten Beast's Hide", "From something no catalogue names. Buyers price it by weight and fear."),
         "B": ("unwritten_bone", "Unwritten Bone", "A bone with no joint it fits. It belongs to nothing that lived."),
         "C": ("unwritten_thread", "Unwritten Thread", "A thread that has no end you can find."),
         "M": ("unwritten_cog", "Unwritten Cog", "Part of a made thing nobody made."),
         "E": ("blank_herald_seal", "Blank Herald's Seal", "The seal of a herald that announced nothing. Its wax is blank.")},
    12: {"A": ("unmade_hide_raw", "Hide of an Unmade Thing", "It was never born, so it was never skinned. It came off anyway."),
         "B": ("unmade_bone", "Unmade Bone", "A bone that was never inside anything."),
         "C": ("unmade_thread", "Unmade Thread", "A thread that was never spun."),
         "M": ("unmade_gear", "Unmade Gear", "A gear with no teeth that still turns what it touches."),
         "E": ("last_creditor_ledger", "Last Creditor's Ledger", "A ledger from the last thing owed. Every page is your name.")},
}

FLORA = {  # band -> (knit, bitter, cold, fruit); band 1 uses existing items
    2: ("Fen Mallow", "Bitterbog", "Cold Sedge", "Tithe Plum"),
    3: ("Snowknit", "Glass Thistle", "Frostcap", "Ice Quince"),
    4: ("Tawny Wort", "Step Nettle", "Spindle Lichen", "Grass-Realm Fig"),
    5: ("Veinroot", "Drake's Pepper", "Hollow Moss", "Rockheart Apple"),
    6: ("Gloam Lily", "Dusk Fennel", "Pale Cap", "Moonless Pear"),
    7: ("Hushleaf", "Still Fern", "Choir Reed", "Silent Date"),
    8: ("Echo Sorrel", "Twin Thistle", "Mirror Moss", "Doubled Plum"),
    9: ("Crag Ease", "Giant's Pepper", "Ray Kelp", "Summit Fig"),
    10: ("First Bloom", "Dawn Thistle", "Deep Kelp", "First Fruit"),
    11: ("Unwritten Herb", "Unwritten Root", "Unwritten Moss", "Unwritten Fruit"),
    12: ("Unmade Herb", "Unmade Root", "Unmade Moss", "Unmade Fruit"),
}
FLORA_REF = {"knit": (0.2, 30), "bitter": (0.2, 40), "cold": (0.2, 35), "fruit": (0.5, 150)}
FLORA_DESC = {
    "knit": "Pressed into a wound it pulls the edges toward each other. Apothecaries buy it by the bunch.",
    "bitter": "Bitter enough to make an essence draught taste of something worse. The base of most draughts.",
    "cold": "Cold to hold in any weather. Alchemists use it to draw heat out of a paste.",
    "fruit": "Grown in a resource cache that puts it back every reset. Elixir makers pay for it.",
}
SATELLITE_NAMES = {4: "Tetrad Mote", 5: "Pentad Mote", 6: "Hexad Mote", 7: "Heptad Mote", 8: "Octad Mote",
                   9: "Ennead Mote", 10: "Decad Mote", 11: "Hendecad Mote", 12: "Dodecad Mote"}


def slug(s):
    out = "".join(c.lower() if c.isalnum() else "_" for c in s.replace("'", ""))
    while "__" in out:
        out = out.replace("__", "_")
    return out.strip("_")


def mat_ids(b):
    """Ids of the refined and raw materials of band b."""
    if b == 1:
        return dict(bar="steel_billet", wire="binding_wire", leather="cured_hide", stave="heartwood_stave",
                    cloth="linen_bolt", salt="flux_salt", ink="rune_ink", ore="scrap_iron", log="rampart_bowstave",
                    hide="husk_plate", fibre="flax_bundle", bone="brute_tusk", made="pavise_boss",
                    elite="commander_sigil", knit="lockweed", bitter="slate_fern_root", cold="grey_lichen",
                    fruit="barrow_sloe")
    info = BAND_INFO[b]
    m, l, w, c = slug(info["metal"]), slug(info["leather"]), slug(info["wood"]), slug(info["cloth"])
    best = BESTIARY[b]
    fl = FLORA[b]
    return dict(bar=f"{m}_bar", wire=f"{m}_wire", leather=f"{l}_leather", stave=f"{w}_stave", cloth=f"{c}_bolt",
                salt=f"ether_salt_b{b}", ink=f"rune_ink_b{b}", ore=f"{m}_ore", log=f"{w}_log",
                hide=best["A"][0], fibre=best["C"][0], bone=best["B"][0], made=best["M"][0], elite=best["E"][0],
                knit=slug(fl[0]), bitter=slug(fl[1]), cold=slug(fl[2]), fruit=slug(fl[3]))


def settled_id(aff, b):
    g = settled_grade(b)
    return slug(f"{BAND_INFO[g]['grade_word']} {AFF_STONE[aff]}")


# --------------------------------------------------------------------------------------------
# Gear lines: (line id, band-1 exemplar in items-v2, category, material class, noun, station,
#              recipe shape {key: count, '*' marks the primary}, two description openings)
# --------------------------------------------------------------------------------------------
LINES = [
    ("knuckles_p", "iron_knuckles", "melee", "metal", "Knuckles", "forge", {"*bar": 1, "wire": 1},
     ["A pair of knuckle-bars for working hands.", "Your fists, with an argument added."]),
    ("knuckles_f", "notched_dusters", "melee", "metal", "Dusters", "forge", {"*bar": 1, "wire": 1, "made": 1},
     ["Dusters with a ridge for each knuckle, fitted close.", "Close-fitted dusters, every edge filed to your grip."]),
    ("dagger_p", "gutting_knife", "melee", "metal", "Knife", "forge", {"*bar": 1, "leather": 1},
     ["A plain knife, long enough to matter.", "A working knife. Most of what it meets is softer than it."]),
    ("dagger_f", "needle_dirk", "melee", "metal", "Dirk", "forge", {"*bar": 1, "leather": 1, "made": 1},
     ["A narrow dirk for finding the gap.", "A dirk ground thin enough to slip between plates."]),
    ("blade_p", "militia_blade", "melee", "metal", "Blade", "forge", {"*bar": 2, "wire": 1},
     ["A one-handed sword, plain and honest.", "An issue sword: stamped, numbered, dependable."]),
    ("blade_f", "duelling_sword", "melee", "metal", "Sword", "forge", {"*bar": 2, "wire": 1, "made": 1},
     ["A balanced sword made by someone who fought with one.", "A long one-handed sword with a quiet edge."]),
    ("axe_p", "felling_axe", "melee", "metal", "Axe", "forge", {"*bar": 2, "stave": 1},
     ["A one-handed axe. The cut keeps working after it lands.", "A hatchet grown up. It opens what it hits."]),
    ("axe_f", "bearded_axe", "melee", "metal", "Bearded Axe", "forge", {"*bar": 2, "stave": 1, "made": 1},
     ["A bearded axe, hooked for shields and ankles.", "A broad bearded head on a short haft."]),
    ("hammer_p", "flanged_mace", "melee", "metal", "Mace", "forge", {"*bar": 2, "stave": 1},
     ["A flanged mace. It does not care which flange arrives.", "A mace for things wearing more than you are."]),
    ("hammer_f", "lead_cored_mace", "melee", "metal", "Warhammer", "forge", {"*bar": 3, "stave": 1, "made": 1},
     ["A warhammer with a beak behind the face.", "A short warhammer, weighted forward."]),
    ("polearm_p", "ash_spear", "melee", "metal", "Spear", "forge", {"*stave": 2, "bar": 1},
     ["A spear: be further away than the other one.", "A plain spear on a long haft."]),
    ("polearm_f", "partisan", "melee", "metal", "Partisan", "forge", {"*stave": 2, "bar": 1, "made": 1},
     ["A partisan with a broad head and side lugs.", "A partisan built to hold a doorway."]),
    ("great_p", "war_maul", "melee", "metal", "Maul", "forge", {"*bar": 3, "stave": 1},
     ["A two-handed maul. One swing, one decision.", "A great maul: both hands, all of your attention."]),
    ("great_f", "tithe_cutter", "melee", "metal", "Greatsword", "forge", {"*bar": 3, "leather": 1, "made": 1},
     ["A greatsword long enough to need its own plan.", "A two-handed blade with a ricasso to choke up on."]),
    ("thrown_p", "throwing_knives", "ranged", "metal", "Throwing Knives", "forge", {"*bar": 1, "leather": 1},
     ["A roll of six balanced throwing knives. Most come back.", "Throwing knives in a bandolier, weighted at the tip."]),
    ("thrown_f", "short_javelins", "ranged", "metal", "Javelins", "forge", {"*stave": 2, "bar": 1, "made": 1},
     ["Three short javelins. Each goes through the first thing.", "A quiver of javelins with long iron shanks."]),
    ("sling_p", "cord_sling", "ranged", "cloth", "Sling", "loom", {"*cloth": 1},
     ["A sling: a cord, a pouch and whatever is on the ground.", "A braided sling that never runs out of stones."]),
    ("sling_f", "staff_sling", "ranged", "leather", "Staff Sling", "leatherworks", {"*leather": 1, "stave": 1, "bone": 1},
     ["A staff sling for throwing over walls.", "A sling on a pole; it throws a stone the size of a fist."]),
    ("bow_p", "hunting_bow", "ranged", "wood", "Bow", "bowyer", {"*stave": 2, "fibre": 1},
     ["A hunting bow with a long, easy draw.", "A plain self bow. Stand still and it pays."]),
    ("bow_f", "rampart_bow", "ranged", "wood", "Recurve", "bowyer", {"*stave": 2, "fibre": 1, "bone": 1},
     ["A recurve that holds its draw.", "A war recurve, short enough to turn with."]),
    ("crossbow_p", "gate_crossbow", "ranged", "wood", "Crossbow", "bowyer", {"*stave": 1, "bar": 1, "wire": 1},
     ["A lever crossbow. It does not care how many stars you have.", "A crossbow spanned by a lever, one bolt at a time."]),
    ("crossbow_f", "windlass_arbalest", "ranged", "wood", "Arbalest", "bowyer", {"*stave": 2, "bar": 1, "wire": 1, "bone": 1},
     ["An arbalest with a crank. One very final noise.", "A heavy arbalest; the windlass hangs at the hip."]),
    ("flue_p", "tin_flue", "ranged", "metal", "Flue", "forge", {"*bar": 1, "salt": 1},
     ["A runed pipe that coughs your own reflux out as shot.", "A plain flue: you cast, it vents, something falls over."]),
    ("flue_f", "brass_flue", "ranged", "metal", "Long Flue", "forge", {"*bar": 2, "salt": 1, "made": 1},
     ["A long flue with tight seams; less of the heat comes back up your arm.", "A long-barrelled flue, runed along every seam."]),
    ("buckler_p", "buckler", "offhand", "metal", "Buckler", "forge", {"*bar": 1, "leather": 1},
     ["A small round buckler, back in place before the next blow.", "A fist-sized boss with a rim. Quick, not deep."]),
    ("shield_p", "plank_shield", "offhand", "wood", "Shield", "bowyer", {"*stave": 2, "bar": 1},
     ["A round shield of planks with a boss.", "A plain shield. It takes what it is given."]),
    ("shield_f", "banded_round_shield", "offhand", "metal", "Heater Shield", "forge", {"*bar": 2, "leather": 1, "made": 1},
     ["A heater shield, rimmed and faced.", "A banded heater shield with a fitted grip."]),
    ("sump_p", "clay_sump", "offhand", "metal", "Sump", "alchemist", {"*salt": 1, "bar": 1},
     ["A stoppered sump: some of what your casting leaves settles in it instead of you.", "A squat sump-jar. It hums when it is full."]),
    ("tablet_f", "runesetters_slate", "offhand", "metal", "Tablet", "runesetter", {"*salt": 2, "wire": 1, "made": 1},
     ["A focus tablet with a working written on it. Fewer mistakes, less waste.", "A runed tablet: someone else's working, and theirs was better."]),
    ("light_head_p", "oilcloth_hood", "head", "cloth", "Hood", "loom", {"*cloth": 1},
     ["A hood that sheds rain and a little heat.", "A close hood; it breathes."]),
    ("light_body_p", "padded_jack", "body", "cloth", "Jack", "loom", {"*cloth": 2, "wire": 1},
     ["A quilted jack. It breathes, which matters more than you think.", "A padded jack, quilted in diamonds."]),
    ("light_hands_p", "kid_gloves", "hands", "cloth", "Gloves", "loom", {"*cloth": 1},
     ["Soft gloves; you can feel the grip.", "Thin gloves, close at the wrist."]),
    ("light_feet_p", "soft_runners", "feet", "cloth", "Runners", "loom", {"*cloth": 1, "wire": 1},
     ["Soft runners with no heel and no noise.", "Light shoes for people who are paid to arrive."]),
    ("light_body_f", "delvers_long_coat", "body", "cloth", "Long Coat", "loom", {"*cloth": 3, "wire": 1, "bone": 1},
     ["A long coat, waxed, vented and mostly pockets.", "A delving coat cut long, with a hood rolled at the collar."]),
    ("med_head_p", "boiled_cap", "head", "leather", "Cap", "leatherworks", {"*leather": 1},
     ["A boiled cap, cooked until it gave up being skin.", "A stiff cap with a brow-band."]),
    ("med_body_p", "boiled_leather_cuirass", "body", "leather", "Cuirass", "leatherworks", {"*leather": 3, "wire": 1},
     ["A cuirass of boiled leather, stiff as a door for the first month.", "A moulded leather cuirass laced at the side."]),
    ("med_hands_p", "hide_bracers", "hands", "leather", "Bracers", "leatherworks", {"*leather": 1},
     ["Bracers between an edge and the arm you need.", "Laced bracers with a rib down the forearm."]),
    ("med_feet_p", "hobnailed_boots", "feet", "leather", "Boots", "leatherworks", {"*leather": 1, "wire": 1},
     ["Hobnailed boots. You stay where you stood.", "Studded boots that grip on any floor."]),
    ("med_body_f", "ringed_hauberk", "body", "leather", "Brigandine", "leatherworks", {"*leather": 3, "bar": 1, "bone": 1},
     ["A brigandine: plates riveted inside a leather coat.", "A fitted brigandine; every plate sits where the last blow landed."]),
    ("heavy_head_p", "kettle_helm", "head", "metal", "Helm", "forge", {"*bar": 2, "leather": 1},
     ["A helm with a brim for things falling off walls.", "A plain helm, riveted, with a nasal."]),
    ("heavy_body_p", "plate_cuirass", "body", "metal", "Plate", "forge", {"*bar": 6, "leather": 1},
     ["Plate front and back. The heat has nowhere to go, and neither do you.", "A plate cuirass with a fauld."]),
    ("heavy_hands_p", "plate_mitts", "hands", "metal", "Gauntlets", "forge", {"*bar": 2, "leather": 1},
     ["Gauntlets with no fingers to lose track of.", "Plate mitts over a leather glove."]),
    ("heavy_feet_p", "greave_boots", "feet", "metal", "Sabatons", "forge", {"*bar": 2, "leather": 1},
     ["Sabatons. Stairs become a negotiation.", "Steel to the toe and plate to the knee."]),
    ("heavy_body_f", "fitted_harness", "body", "metal", "Harness", "forge", {"*bar": 6, "leather": 2, "made": 1},
     ["A full harness, measured for you.", "A fitted harness. The price says so twice."]),
    ("frame_p", "delver_frame", "back", "leather", "Frame", "leatherworks", {"*leather": 2, "stave": 1},
     ["A load-bearing frame for hauling corpses out.", "A delving frame with a hip band and lashing points."]),
    ("belt_p", "tool_belt", "belt", "leather", "Belt", "leatherworks", {"*leather": 1, "wire": 1},
     ["A belt with loops for what you want without looking.", "A wide belt: braces, rings and a buckle you can work one-handed."]),
]
LINE_LOOK = {"light_head_p": "hood", "light_body_p": "padded", "light_hands_p": "gloves", "light_feet_p": "boots",
             "light_body_f": "coat", "med_head_p": "cap", "med_body_p": "hide", "med_hands_p": "bracers",
             "med_feet_p": "tallboots", "med_body_f": "hide", "frame_p": "frame", "belt_p": "belt"}
# Band-1 recipes that cannot use the generic shape (the item is cheaper than the band's cloth).
BAND1_SHAPE = {"sling_p": {"*fibre": 1}}
LINE_MAKES = {"sling_p": 2}  # a bolt of cloth braids two slings
# Lines that also exist at bands 11 and 12 (the few "beyond ten" items).
BEYOND_LINES = {"knuckles_p", "dagger_p", "blade_p", "axe_p", "hammer_p", "polearm_p", "great_p",
                "thrown_p", "bow_p", "crossbow_p", "flue_p", "sling_p",
                "light_body_p", "med_body_p", "heavy_body_p", "heavy_head_p"}
# Band-1 items that are the first member of a line (so every line has a band-1 entry).
BAND1_LINE = {l[1]: l[0] for l in LINES}
BAND1_LINE.update({"river_stone": "charm_water", "hearth_coal_charm": "charm_fire", "plumb_weight_charm": "charm_earth",
                   "kite_bone_charm": "charm_wind", "fulgurite_charm": "charm_lightning",
                   "brine_phial": "talisman_water", "tinder_knot": "talisman_fire", "keystone_chip": "talisman_earth",
                   "reed_whistle": "talisman_wind", "split_nail": "talisman_lightning",
                   "cooling_coil": "coil", "menders_thread": "thread",
                   "dim_mote": "satellite", "paired_mote": "satellite", "trine_mote": "satellite",
                   "arrow_bundle": "arrows", "bolt_case": "bolts", "lead_shot": "shot",
                   "barbed_arrows": "barbed_arrows", "bitter_draught": "essence_draught",
                   "cooling_paste": "cooling_paste", "numbing_salt": "numbing_salt", "field_dressing": "poultice",
                   "spoils_strongbox": "spoils_strongbox", "spoils_relics": "spoils_relics",
                   "spoils_salvage": "spoils_salvage", "slaughter_stone": "catalyst",
                   "steel_billet": "mat_bar", "binding_wire": "mat_wire", "cured_hide": "mat_leather",
                   "heartwood_stave": "mat_stave", "flux_salt": "mat_salt", "rune_ink": "mat_ink",
                   "scrap_iron": "mat_ore"})

RARITY_BY_TIER = {0: "salvage", 1: "plain", 2: "fine", 3: "runed", 4: "cursed"}

# How a stat moves with band [MODEL]; see design/10 section 4.
SCALE = {
    "melee_damage_mult": "whole", "ranged_damage_mult": "whole",
    "ranged_damage_flat": "strike", "block": "guard",
    "armour": "add1", "wound_resist": "add1", "poise": "add1", "nether_leash_bonus": "add1",
    "projection_hp_bonus": "add1", "wisp_reach_bonus": "add2",
    "carry_capacity": "weight", "worn_allowance": "weight", "max_health": "body",
    "reflux_shed_mult": "bonus", "cost_mult": "bonus", "reflux_gain_mult": "bonus", "ranged_interval_mult": "bonus",
    "move_speed_mult": "bonus", "wound_mend_mult": "bonus", "strike_poise_mult": "bonus",
    "temper_cost_mult": "bonus", "temper_progress_mult": "bonus", "nether_strike_mult": "bonus",
    "melee_cooldown_mult": "bonus_hands",  # a weapon's speed is its family; gloves' speed scales
}


def scale_stat(key, v, b, slot):
    if key.startswith("cost_mult_") or key.startswith("ability_damage_mult"):
        mode = "bonus"
    else:
        mode = SCALE.get(key, "keep")
    if mode == "bonus_hands":
        mode = "bonus" if slot != "weapon" else "keep"
    g = G(b)
    if mode == "whole":
        return r3(v * g)
    if mode == "strike":
        return round(v * S(b) * g, 1)
    if mode == "guard":
        return round(v * B(b) * g)
    if mode == "add1":
        return round(v * g, 1)
    if mode == "add2":
        return round(v * g, 2)
    if mode == "weight":
        return round(v * W(b), 1)
    if mode == "body":
        return round(v * B(b), 1)
    if mode == "bonus":
        return r3(1 + (v - 1) * g)
    return v


# --------------------------------------------------------------------------------------------
# Building
# --------------------------------------------------------------------------------------------
ITEMS = OrderedDict()
RECIPES = []


def add(iid, item):
    assert iid not in ITEMS, f"duplicate id {iid}"
    ITEMS[iid] = item
    return item


def recipe(station, b, inputs, fee, makes=1, stars=None, hours=None, note=None):
    r = OrderedDict()
    r["station"] = station
    r["grade"] = 0 if station == "camp" else grade(b)
    r["stars"] = stars if stars is not None else max(1, b - 1)
    r["inputs"] = OrderedDict((k, v) for k, v in inputs.items() if v > 0)
    r["fee"] = int(max(0, round(fee)))
    r["makes"] = makes
    r["hours"] = hours if hours is not None else (1 if station in ("camp", "alchemist") else 1 + grade(b))
    if note:
        r["note"] = note
    return r


def inputs_value(inputs):
    return sum(ITEMS[k]["value"] * n for k, n in inputs.items())


def fixed_value_recipe(station, b, inputs, value, factor, stars=None, hours=None, max_makes=40):
    """A recipe for an item whose value is already set: choose the smallest batch whose fee is
    positive, so that value x makes = factor x (inputs + fee)."""
    iv = inputs_value(inputs)
    for makes in range(1, max_makes + 1):
        fee = value * makes / factor - iv
        if fee >= 0.05 * iv:
            return recipe(station, b, inputs, fee, makes, stars, hours)
    return recipe(station, b, inputs, 0, max_makes, stars, hours, note="inputs worth more than the batch")


def derived_item_value(inputs, fee_frac, makes, factor):
    iv = inputs_value(inputs)
    fee = fee_frac * iv
    return nice(factor * (iv + fee) / makes), fee


def base_item(name, slot, kind, category, b, weight, value, desc, stack, **extra):
    it = OrderedDict()
    it["name"] = name
    it["slot"] = slot
    it["kind"] = kind
    it["category"] = category
    it["band"] = b
    for k in ("rarity", "family", "class", "two_handed", "needs_both_arms", "affinity"):
        if k in extra:
            it[k] = extra.pop(k)
    it["weight"] = weight
    it["value"] = value
    it["stack"] = stack
    for k, v in extra.items():
        it[k] = v
    it["desc"] = desc
    return it


def stack_for_weight(w):
    if w >= 3:
        return 1
    if w >= 1:
        return 5
    return 20


# ---------- band 1: the approved design/06 catalogue plus the live ids ----------
def category_of(it):
    slot, kind = it.get("slot", ""), it.get("kind", "")
    fam = it.get("family", "")
    if slot == "weapon":
        return "melee"
    if slot in ("ranged", "offhand", "head", "body", "hands", "feet", "back", "belt", "satellite", "trinket"):
        return slot
    return {"ammo": "ammo", "consumable": "consumable", "material": "material", "catalyst": "catalyst",
            "scroll": "scroll"}.get(kind, "trade")


def build_band1():
    v2 = json.loads(V2_PATH.read_text(encoding="utf-8"))
    live = json.loads(LIVE_PATH.read_text(encoding="utf-8"))
    v2i, livei = v2["items"], live["items"]
    retuned = {"river_stone", "cooling_coil"}  # design/06 section 5, approved 2026-10-12
    ids = list(v2i.keys()) + [k for k in livei if k not in v2i]
    remains_ids = set()
    for e in json.loads((ROOT / "game/data/enemies.json").read_text(encoding="utf-8"))["enemies"].values():
        remains_ids.add(e.get("remains", ""))
    for iid in ids:
        src = dict(v2i.get(iid, {}))
        if iid in livei:
            lv = livei[iid]
            for k in ("name", "desc", "value", "weight"):
                if k in lv and not (iid in retuned and k == "desc"):
                    src[k] = lv[k]
            if "kind" in lv:
                src["kind"] = lv["kind"]
            if "teaches" in lv:
                src["teaches"] = lv["teaches"]
            if "stats" in lv and iid not in retuned and "stats" not in src:
                src["stats"] = lv["stats"]
        slot = src.get("slot", "")
        if slot == "off_hand":
            slot = "offhand"
        kind = src.get("kind", "")
        if iid in remains_ids:
            kind = "remains"
        elif kind == "loot":
            kind = "trade"
        elif kind == "" and slot == "" and iid.startswith("spoils_"):
            kind = "spoils"
        elif kind == "":
            kind = "gear" if slot else "trade"
        src["slot"], src["kind"] = slot, kind
        cat = category_of(src)
        if kind == "remains":
            cat = "remains"
        if kind == "spoils":
            cat = "spoils"
        b = 1
        if slot == "satellite":
            b = max(1, math.ceil(src.get("stats", {}).get("satellite_rate", 1.0)))
        rarity = None
        if kind == "gear":
            rarity = "unique" if src.get("unique") else RARITY_BY_TIER[src.get("tier", 1)]
        extra = {}
        if rarity:
            extra["rarity"] = rarity
        for k in ("family", "class", "two_handed", "needs_both_arms"):
            if k in src:
                extra[k] = src[k]
        if src.get("stats"):
            extra["stats"] = src["stats"]
        for k in ("rune", "base", "toll", "effect", "effect_text", "grows", "use", "ammo_kind", "count",
                  "recover", "ammo_damage_mult", "on_hit", "catalyst", "teaches"):
            if k in src:
                extra[k] = src[k]
        if iid in BAND1_LINE:
            extra["line"] = BAND1_LINE[iid]
        stack = 1 if kind == "gear" or kind == "scroll" else (10 if kind in ("ammo", "consumable") else stack_for_weight(src["weight"]))
        add(iid, base_item(src["name"], slot, kind, cat, b, src["weight"], src["value"], src["desc"], stack, **extra))
    return v2, live


def wardrobe_looks():
    w = json.loads((ROOT / "game/data/wardrobe.json").read_text(encoding="utf-8"))
    for iid, piece in w["items"].items():
        if iid in ITEMS:
            ITEMS[iid]["look"] = piece
    return set(w["pieces"].keys())


# ---------- band-1 additions the new systems need ----------
def build_band1_additions():
    def a(iid, name, kind, cat, w, v, desc, **extra):
        add(iid, base_item(name, "", kind, cat, 1, w, v, desc, extra.pop("stack", stack_for_weight(w)), **extra))
    a("flax_bundle", "Flax Bundle", "material", "raw", 1.0, 25, "Retted flax off the Stubble's one wet corner. Spun, it is linen.", source=["gather", "shop"])
    a("linen_bolt", "Linen Bolt", "material", "material", 1.0, 40, "A bolt of plain linen. Padding, dressings, the inside of everything.", line="mat_cloth", source=["craft", "shop"])
    a("lockweed", "Lockweed", "reagent", "reagent", 2.0, 90, "Cut from the basin wall of the Drowned Lock, which grows it back every dawn. It knits flesh.", source=["cache"], role="knit")
    a("barrow_sloe", "Barrow Sloe", "reagent", "reagent", 0.5, 150, "A sour sloe that grows only on passage mounds. The first fruit elixir makers learn on.", source=["gather"], role="fruit")
    a("gleaner_hoard", "Gleaner's Hoard", "remains", "remains", 1.5, 180, "Whatever a Gleaner had picked up: buttons, nails, a tooth. Sold by the bag.", source=["drop"])
    a("lurker_jaw", "Sod-Lurker Jaw", "remains", "remains", 3.0, 320, "A jaw built to close upward. Bonesetters use the teeth as pegs.", source=["drop"])
    a("thornback_hide", "Thornback Hide", "remains", "remains", 25.0, 900, "Most of a Thornback's back, spines and all. More than a starting pack holds.", source=["drop"])
    a("thornback_horn", "Thornback Horn", "remains", "remains", 8.0, 420, "A grazer's horn, worn smooth on one side from rubbing on stones.", source=["drop"])
    for aff in AFFS:
        a(settled_id(aff, 1), f"Flecked {AFF_STONE[aff]}", "material", "settled_ether", 0.2, 150,
          f"A fleck of {AFF_LABEL[aff].lower()} ether that pooled and set in thin ground. Charms and charges are made of it.",
          affinity=aff, source=["gather"], line=f"settled_{aff}")
    # proofs of the named deviants and bosses of design/07 5.6 (the Collection Office buys them)
    proofs = [("proof_old_hapenny", "Old Ha'penny's Purse", 1200, "A purse of other people's coins, sewn shut. Proof he will not be back."),
              ("proof_widow_mask", "The Widow-Mask", 1800, "The mask of the one who came looking for you. The Collection Office pays for it, and asks no questions."),
              ("proof_dray", "Dray's Harness Ring", 1500, "The iron ring Dray's sledge hung from. It took two hands to lift off him."),
              ("proof_long_sorrow", "Long Sorrow's Collar", 1600, "A braided collar off the harrier that led the pack."),
              ("proof_wet_wick", "Wet Wick's Snuffer", 1400, "A snuffer on a chain. Everything it touched went dark."),
              ("proof_unseen_fletcher", "The Unseen Fletcher's Nock", 1700, "A carved nock from the archer you never saw draw."),
              ("proof_auditor", "The Auditor's Ledger", 2500, "The ledger chained to the Auditor's arm. Every entry is a debt; one is yours."),
              ("proof_muster_captain", "The Muster-Captain's Standard", 4000, "A war-camp's standard. Proof the Muster is broken, for a while.")]
    for iid, name, v, desc in proofs:
        a(iid, name, "proof", "proof", 1.0 if "standard" not in iid else 4.0, v, desc, source=["drop"])
    # tempering manuals (design/05 section 5; $2,500 there)
    manuals = [("hard_knit", "Hard Knit", "", "Health returns faster between fights."),
               ("rooted_stance", "Rooted Stance", "", "Your own poise grows."),
               ("yielding_flesh", "Yielding Flesh", "water", "The first hit of each exchange lands soft."),
               ("brine_blood", "Brine Blood", "water", "Lingering harm on you ends sooner."),
               ("banked_coals", "Banked Coals", "fire", "Reflux pain starts later."),
               ("seared_shut", "Seared Shut", "fire", "Some wounds never open."),
               ("ballast", "Ballast", "earth", "You are shoved less far and stagger shorter."),
               ("settled_weight", "Settled Weight", "earth", "Standing still, you take less."),
               ("loose_joints", "Loose Joints", "wind", "You recover sooner out of a dash."),
               ("glancing_skin", "Glancing Skin", "wind", "Shots on the run barely bite."),
               ("jolt_reflex", "Jolt Reflex", "lightning", "Getting hit throws you clear."),
               ("scorched_channels", "Scorched Channels", "lightning", "Lock-outs are shorter.")]
    for tid, name, aff, what in manuals:
        who = f"someone with the {aff} affinity" if aff else "anyone"
        extra = {"teaches_technique": tid, "source": ["shop", "drop"]}
        if aff:
            extra["affinity"] = aff
        a(f"manual_{tid}", f"Manual: {name}", "manual", "manual", 0.4, 2500,
          f"A tempering manual for {who}: {what} Read once in the yard; the manual is used up.", stack=1, **extra)
    # keys and quest placeholders tied to design/07's dungeons
    keys = [("key_counting_house_vault", "Counting-House Vault Key", "A key off the Auditor's chain. It opens the vault chest at the bottom of the Old Counting-House, once."),
            ("key_drowned_lock_wheel", "Sluice-Wheel Handle", "Fits the sluice in the Drowned Lock. Turning it drains the basin for a while; nobody knows what else it does."),
            ("key_muster_pass", "Muster Pass", "A camp pass, cut from a dead sentry's belt. The gate guards of the Muster look at it a moment longer."),
            ("quest_registry_papers", "Registry Papers", "Your papers as an archhuman, stamped in Passage Row. Losing them is a week in a queue."),
            ("quest_sealed_letter", "Sealed Letter", "A letter you were paid to carry and not to open. Placeholder for courier work.")]
    for iid, name, desc in keys:
        a(iid, name, "key" if iid.startswith("key_") else "quest", "key" if iid.startswith("key_") else "quest", 0.1, 0, desc,
          stack=1, sellable=False, placeholder=True, source=["drop" if iid.startswith("key_") else "quest"])


# ---------- materials, reagents, remains for bands 2..12 ----------
def build_materials(b):
    info = BAND_INFO[b]
    m = mat_ids(b)
    v, w = V(b), W(b)
    mc = {k: MAT_CLAUSE[k][b] for k in MAT_CLAUSE}
    # remains first (they are inputs)
    for role, (rid, name, desc) in BESTIARY[b].items():
        rk, rv = REMAINS_REF[role]
        uses = {"A": "Tanned, it is the band's leather.", "B": "A crafter's masterwork piece for bows, slings and coats.",
                "C": "Spun, it is the band's cloth.", "M": "A smith's masterwork piece; the metal is the band's own.",
                "E": "Good only for selling, and very good for that."}[role]
        add(rid, base_item(name, "", "remains", "remains", b, kg(rk * w), nice(rv * v), f"{desc} {uses}",
                           stack_for_weight(rk * w), role={"A": "hide", "B": "bone", "C": "fibre", "M": "made", "E": "trophy"}[role],
                           source=["drop"]))
    # raw
    add(m["ore"], base_item(f"{info['metal']} Ore", "", "material", "raw", b, kg(2.0 * w), nice(45 * v),
                            f"Ore of {info['metal'].lower()}, from veins and resource caches. {mc['metal']}", stack_for_weight(2.0 * w),
                            source=["cache", "gather"]))
    add(m["log"], base_item(f"{info['wood']} Log", "", "material", "raw", b, kg(4.0 * w), nice(60 * v),
                            f"A length of {info['wood'].lower()}, felled and trimmed. {mc['wood']}", 1, source=["gather"]))
    add(m["salt"], base_item(f"{info['word']} Ether Salt", "", "material", "settled_ether", b, kg(0.3), nice(100 * v),
                             f"Plain ether that pooled and crystallised in rich ground. Flux for smiths, base for alchemists, ink for runesetters.",
                             20, line="mat_salt", source=["gather", "drop"]))
    # flora (reagents)
    for role, name in zip(("knit", "bitter", "cold", "fruit"), FLORA[b]):
        fk, fv = FLORA_REF[role]
        add(slug(name), base_item(name, "", "reagent", "reagent", b, kg(fk * w), nice(fv * v), f"{name}. {FLORA_DESC[role]}",
                                  20 if role != "fruit" else 10, role=role, source=["gather"] if role != "fruit" else ["cache"],
                                  line=f"reagent_{role}"))
    # refined (derived values)
    def refined(iid, name, inputs, makes, fee_frac, desc, wt, line, station):
        val, fee = derived_item_value(inputs, fee_frac, makes, 0.95)
        add(iid, base_item(name, "", "material", "material", b, kg(wt), val, desc, stack_for_weight(wt), line=line,
                           source=["craft"], recipe=recipe(station, b, inputs, fee, makes)))
    refined(m["bar"], f"{info['metal']} Bar", {m["ore"]: 2}, 1, 0.15, f"A bar of {info['metal'].lower()}. {mc['metal']}", 2.0 * w, "mat_bar", "forge")
    refined(m["wire"], f"{info['metal']} Wire", {m["bar"]: 1}, 4, 0.1, f"Drawn {info['metal'].lower()} wire. It holds grips, rims and rings together.", 0.3, "mat_wire", "forge")
    refined(m["leather"], f"{info['leather']} Leather", {m["hide"]: 1}, 4, 0.05, f"Tanned and cut into working sides. {mc['leather']}", 2.0 * w, "mat_leather", "leatherworks")
    refined(m["stave"], f"{info['wood']} Stave", {m["log"]: 1}, 2, 0.15, f"Split, seasoned and straight. {mc['wood']}", 1.5 * w, "mat_stave", "bowyer")
    refined(m["cloth"], f"{info['cloth']} Bolt", {m["fibre"]: 1}, 4, 0.05, f"A bolt of woven cloth. {mc['cloth']}", 1.0 * w, "mat_cloth", "loom")
    refined(m["ink"], f"{info['word']} Rune Ink", {m["salt"]: 2, m["bitter"]: 1}, 1, 0.3,
            "Enough ink to write one rune onto one thing of this band. The runesetter does not give refunds.", 0.2, "mat_ink", "alchemist")
    # settled ether at a new grade
    if b in SETTLED_GRADES:
        for aff in AFFS:
            add(settled_id(aff, b), base_item(f"{info['grade_word']} {AFF_STONE[aff]}", "", "material", "settled_ether", b,
                                              0.2, nice(150 * v),
                                              f"{AFF_LABEL[aff]} ether that pooled and set in rich ground, {info['grade_word'].lower()} all the way through. Charms, talismans and charges are made of it.",
                                              20, affinity=aff, source=["gather"], line=f"settled_{aff}"))


def band1_recipes():
    """Recipes for band-1 materials whose values design/06 already fixed."""
    m = mat_ids(1)
    for iid, inputs, station in [("steel_billet", {"scrap_iron": 2, "flux_salt": 1}, "forge"),
                                 ("binding_wire", {"steel_billet": 1}, "forge"),
                                 ("cured_hide", {"husk_plate": 1}, "leatherworks"),
                                 ("heartwood_stave", {"rampart_bowstave": 1}, "bowyer"),
                                 ("linen_bolt", {"flax_bundle": 2}, "loom"),
                                 ("rune_ink", {"censer_ash": 1, "flux_salt": 1}, "alchemist")]:
        it = ITEMS[iid]
        it["recipe"] = fixed_value_recipe(station, 1, inputs, it["value"], 1.0, stars=1)
        it.setdefault("source", ["craft", "drop"])
    ITEMS["scrap_iron"]["category"] = "raw"
    ITEMS["flux_salt"]["category"] = "settled_ether"
    for iid, role in (("slate_fern_root", "bitter"), ("grey_lichen", "cold")):
        ITEMS[iid]["kind"], ITEMS[iid]["category"], ITEMS[iid]["role"] = "reagent", "reagent", role
    ITEMS["lockweed"]["line"] = "reagent_knit"
    ITEMS["slate_fern_root"]["line"] = "reagent_bitter"
    ITEMS["grey_lichen"]["line"] = "reagent_cold"
    ITEMS["barrow_sloe"]["line"] = "reagent_fruit"
    ITEMS["censer_ash"]["role"] = "ink"
    ITEMS["brute_hide"]["role"] = "hide_heavy"
    ITEMS["harrier_pelt"]["role"] = "fur"
    ITEMS["rampart_bowstave"]["role"] = "wood"


# ---------- gear lines ----------
def gear_recipe(spec, b, value):
    line, ex, cat, mclass, noun, station, shape, _ = spec
    m = mat_ids(b)
    fine = line.endswith("_f")
    if b == 1 and line in BAND1_SHAPE:
        shape = BAND1_SHAPE[line]
    inputs = OrderedDict()
    prim_key = None
    for k, n in shape.items():
        key = k.lstrip("*")
        if k.startswith("*"):
            prim_key = key
        inputs[m[key]] = n
    # scale the primary to put inputs near 45% of the price (capped at 8)
    makes = LINE_MAKES.get(line, 1)
    total = value * makes
    others = inputs_value({k: n for k, n in inputs.items() if k != m[prim_key]})
    unit = ITEMS[m[prim_key]]["value"]
    n = max(shape["*" + prim_key], min(8, round((0.45 * total - others) / unit)))
    inputs[m[prim_key]] = n
    iv = inputs_value(inputs)
    fee = max(0.1 * total, 0.75 * total - iv)
    return recipe(station, b, inputs, fee, makes, stars=b if fine else max(1, b - 1),
                  hours=(2 if fine else 1) * (1 + grade(b)))


def make_line_item(spec, b):
    line, ex, cat, mclass, noun, station, shape, openings = spec
    exi = ITEMS[ex]
    info = BAND_INFO[b]
    mat_name = info[mclass]
    name = f"{mat_name} {noun}"
    stats = OrderedDict((k, scale_stat(k, v, b, exi["slot"])) for k, v in exi.get("stats", {}).items())
    value = nice(exi["value"] * V(b))
    weight = kg(exi["weight"] * W(b))
    desc = f"{openings[b % 2]} {MAT_CLAUSE[mclass][b]}"
    extra = OrderedDict(rarity=exi.get("rarity", "plain"))
    for k in ("family", "class", "two_handed", "needs_both_arms"):
        if k in exi:
            extra[k] = exi[k]
    extra["stats"] = stats
    extra["line"] = line
    extra["material"] = mat_name
    if line in LINE_LOOK:
        extra["look"] = LINE_LOOK[line]
    fine = line.endswith("_f")
    extra["source"] = ["drop", "craft", "shop_rotation"] if fine else ["shop", "drop", "craft"]
    iid = slug(name)
    it = add(iid, base_item(name, exi["slot"], "gear", cat, b, weight, value, desc, 1, **extra))
    it["recipe"] = gear_recipe(spec, b, value)
    return iid


def band1_gear_recipes():
    for spec in LINES:
        ex = spec[1]
        if "recipe" not in ITEMS[ex]:
            ITEMS[ex]["recipe"] = gear_recipe(spec, 1, ITEMS[ex]["value"])
            ITEMS[ex].setdefault("source", ["shop", "drop", "craft"])


def make_worn_lines(b):
    """Back-slot frames are in LINES; trinkets and satellites are built here."""
    info = BAND_INFO[b]
    m = mat_ids(b)
    metal = info["metal"]
    out = []
    for aff in AFFS:
        st = AFF_STONE[aff]
        sid = settled_id(aff, b)
        # cost charm
        val = nice(700 * V(b))
        name = f"{metal} {AFF_WORD[aff]} Charm"
        stats = {f"cost_mult_{aff}": r3(1 - 0.10 * G(b))}
        it = add(slug(name), base_item(name, "trinket", "gear", "trinket", b, kg(0.3 * W(b)), val,
                                       f"A charm set with {st.lower()} in {metal.lower()}. {AFF_LABEL[aff]} abilities cost less essence.",
                                       1, rarity="plain", affinity=aff, stats=stats, line=f"charm_{aff}", material=metal,
                                       source=["shop", "drop", "craft"]))
        inputs = {sid: 1, m["bar"]: 1}
        it["recipe"] = recipe("runesetter", b, inputs, max(0.1 * val, 0.75 * val - inputs_value(inputs)))
        # damage talisman
        val = nice(1800 * V(b))
        name = f"{metal} {AFF_WORD[aff]} Talisman"
        stats = {f"ability_damage_mult_{aff}": r3(1 + 0.06 * G(b))}
        it = add(slug(name), base_item(name, "trinket", "gear", "trinket", b, kg(0.2 * W(b)), val,
                                       f"A talisman of {st.lower()} bound in {metal.lower()} wire. {AFF_LABEL[aff]} abilities hit a little harder.",
                                       1, rarity="fine", affinity=aff, stats=stats, line=f"talisman_{aff}", material=metal,
                                       source=["drop", "craft", "shop_rotation"]))
        inputs = {sid: 2, m["wire"]: 1}
        it["recipe"] = recipe("runesetter", b, inputs, max(0.1 * val, 0.75 * val - inputs_value(inputs)), stars=b)
    val = nice(850 * V(b))
    name = f"{metal} Cooling Coil"
    it = add(slug(name), base_item(name, "trinket", "gear", "trinket", b, kg(0.5 * W(b)), val,
                                   f"A coil of {metal.lower()} that runs cold when you run hot. Reflux bleeds off a little faster.",
                                   1, rarity="plain", stats={"reflux_shed_mult": r3(1 + 0.15 * G(b))}, line="coil", material=metal,
                                   source=["shop", "drop", "craft"]))
    inputs = {m["bar"]: 1, m["salt"]: 1}
    it["recipe"] = recipe("runesetter", b, inputs, max(0.1 * val, 0.75 * val - inputs_value(inputs)))
    val = nice(1600 * V(b))
    name = f"{info['cloth']} Mender's Thread"
    it = add(slug(name), base_item(name, "trinket", "gear", "trinket", b, 0.1, val,
                                   f"A thread of {info['cloth'].lower()} soaked in {FLORA[b][0].lower()}, wound round the wrist. Healing spent on a lasting wound goes further.",
                                   1, rarity="fine", stats={"wound_mend_mult": r3(1 + 0.10 * G(b))}, line="thread", material=info["cloth"],
                                   source=["drop", "craft"]))
    inputs = {m["cloth"]: 1, m["knit"]: 2}
    it["recipe"] = recipe("alchemist", b, inputs, max(0.1 * val, 0.75 * val - inputs_value(inputs)), stars=b)
    # satellite (found or bought, never made [B])
    if b >= 4:
        name = SATELLITE_NAMES[b]
        add(slug(name), base_item(name, "satellite", "gear", "satellite", b, kg(0.2 + 0.02 * b), nice(2400 * V(b)),
                                  f"A {b}-star satellite. It trickles {b} essence a second into you whether you ask or not. Satellites are found or bought; nobody in town can make one.",
                                  1, rarity="plain", rank=b, stats={"satellite_rate": float(b)}, line="satellite",
                                  source=["shop", "drop"]))


def make_beyond_lines(b):
    for spec in LINES:
        if spec[0] in BEYOND_LINES:
            make_line_item(spec, b)
    for aff in AFFS:
        info = BAND_INFO[b]
        name = f"{info['metal']} {AFF_WORD[aff]} Charm"
        val = nice(700 * V(b))
        m = mat_ids(b)
        it = add(slug(name), base_item(name, "trinket", "gear", "trinket", b, kg(0.3 * W(b)), val,
                                       f"A charm set with {AFF_STONE[aff].lower()} in {info['metal'].lower()}. {AFF_LABEL[aff]} abilities cost less essence.",
                                       1, rarity="plain", affinity=aff, stats={f"cost_mult_{aff}": r3(1 - 0.10 * G(b))},
                                       line=f"charm_{aff}", material=info["metal"], source=["drop", "craft"]))
        inputs = {settled_id(aff, b): 1, m["bar"]: 1}
        it["recipe"] = recipe("runesetter", b, inputs, max(0.1 * val, 0.75 * val - inputs_value(inputs)))
    name = SATELLITE_NAMES[b]
    add(slug(name), base_item(name, "satellite", "gear", "satellite", b, kg(0.2 + 0.02 * b), nice(2400 * V(b)),
                              f"A {b}-star satellite. Its flow is a steady {b} essence a second. Whoever made it, nobody alive did.",
                              1, rarity="plain", rank=b, stats={"satellite_rate": float(b)}, line="satellite", source=["drop", "auction"]))


# ---------- runed items (a Fine item + one rune, written by the runesetter) ----------
RUNE_CAP = 0.10  # [C] an artifact's single effect is usually at most 10%


def rune_value(rune, b):
    v = rune["value"]
    g = G(b)
    if rune["stat"] in ("poise", "wound_resist", "nether_leash_bonus", "projection_hp_bonus", "reflux_pain_shift"):
        return round(v * g, 1)
    if rune["stat"] in ("melee_range_bonus", "wisp_reach_bonus"):
        return round(v * (1 + (g - 1) * 0.5), 2)
    if v > 1:
        return r3(1 + min(RUNE_CAP, (v - 1) * g))
    return r3(1 - min(RUNE_CAP, (1 - v) * g))


RUNE_ROTATION = {
    "melee": ["keen", "quick", "staggering", "long", "venting", "keen", "echo_edged"],
    "ranged": ["true", "light_drawn", "venting", "true", "light_drawn"],
    "body": ["warded", "knitting", "venting", "stubborn", "second_skinned", "yard_worn"],
}
MELEE_F = [l for l in LINES if l[2] == "melee" and l[0].endswith("_f")]
RANGED_F = [l for l in LINES if l[2] == "ranged" and l[0].endswith("_f")]
BODY_F = [l for l in LINES if l[2] == "body" and l[0].endswith("_f")]


def make_runed(b, runes):
    picks = [(MELEE_F[b % len(MELEE_F)], RUNE_ROTATION["melee"][b % 7]),
             (RANGED_F[b % len(RANGED_F)], RUNE_ROTATION["ranged"][b % 5]),
             (BODY_F[b % len(BODY_F)], RUNE_ROTATION["body"][b % 6])]
    m = mat_ids(b)
    for spec, rid in picks:
        base_id = slug(f"{BAND_INFO[b][spec[3]]} {spec[4]}")
        base = ITEMS[base_id]
        rune = runes[rid]
        rv = rune_value(rune, b)
        stats = OrderedDict(base["stats"])
        st = rune["stat"]
        if st in ("poise", "wound_resist", "nether_leash_bonus", "projection_hp_bonus", "reflux_pain_shift",
                  "melee_range_bonus", "wisp_reach_bonus"):
            stats[st] = round(stats.get(st, 0) + rv, 2)
        elif st in stats:
            stats[st] = r3(stats[st] * rv)
        else:
            stats[st] = rv
        name = f"{rune['word']} {base['name']}"
        value = nice(base["value"] * 2.2)
        it = add(slug(name), base_item(name, base["slot"], "gear", base["category"], b, base["weight"], value,
                                       f"{base['name']}, with one {rune['word'].lower()} rune written along it by a runesetter. {RUNE_LINES[rid]}",
                                       1, rarity="runed", **{k: base[k] for k in ("family", "class", "two_handed", "needs_both_arms") if k in base},
                                       stats=stats, rune=rid, base=base_id, material=base["material"],
                                       source=["drop", "craft", "shop_rotation"]))
        if "look" in base:
            it["look"] = base["look"]
        # fee = 0.6 x the value the rune adds (design/10 section 7.4)
        it["recipe"] = recipe("runesetter", b, {base_id: 1, m["ink"]: 1}, 0.6 * (value - base["value"]), 1, stars=b,
                              note="fails 10% of the time: ink and fee lost, item kept (design/06 8.5)")


RUNE_LINES = {
    "keen": "It cuts a little deeper than it should.", "quick": "It is back in your hand before you have decided.",
    "staggering": "Whatever it hits takes a moment to remember where it was.", "long": "It reaches a hand's width further than it measures.",
    "venting": "The writing runs warm after a cast. That is the heat leaving.", "echo_edged": "It bites a little harder on the other side.",
    "true": "Shots correct themselves a little. Do not ask how.", "light_drawn": "The draw comes round sooner than it should.",
    "warded": "What gets past it gets past gently.", "knitting": "Wounds under it close as if they had somewhere to be.",
    "stubborn": "It leans back when you are pushed.", "second_skinned": "In the Netherecho it takes the first of what was meant for you.",
    "yard_worn": "Training in it takes less out of you.",
}


# ---------- cursed and unique items (hand-written) ----------
def variant(base_id, iid, name, b, rarity, desc, stats_mult=None, stats_add=None, weight_mult=1.0, value_mult=3.0,
            toll=None, effect=None, effect_text=None, grows=None):
    base = ITEMS[base_id]
    stats = OrderedDict(base.get("stats", {}))
    for k, f in (stats_mult or {}).items():
        stats[k] = r3(stats.get(k, 1.0) * f)
    for k, a in (stats_add or {}).items():
        stats[k] = round(stats.get(k, 0) + a, 3)
    extra = OrderedDict(rarity=rarity)
    for k in ("family", "class", "two_handed", "needs_both_arms"):
        if k in base:
            extra[k] = base[k]
    extra["stats"] = stats
    if toll:
        extra["toll"] = toll
    if effect:
        extra["effect"] = effect
    if effect_text:
        extra["effect_text"] = effect_text
    if grows:
        extra["grows"] = grows
    extra["base"] = base_id
    extra["source"] = ["drop", "deviant"] if rarity == "cursed" else ["deviant", "feat", "auction"]
    if "look" in base:
        extra["look"] = base["look"]
    return add(iid, base_item(name, base["slot"], "gear", base["category"], b, kg(base["weight"] * weight_mult),
                              nice(base["value"] * value_mult), desc, 1, **extra))


def make_specials():
    # cursed: stronger, with a toll (design/06 6.3)
    variant("gatesteel_partisan", "toll_pike", "Toll-Pike", 2, "cursed",
            "It was set across a road to stop carts. It still thinks it decides who goes past.",
            stats_add={"melee_range_bonus": 0.3, "tip_bonus_add": 0.2, "move_speed_mult": -0.05}, toll="reluctant",
            effect_text="The bonus for striking at the tip is doubled, and it reaches further than any partisan.")
    ITEMS["toll_pike"]["stats"]["move_speed_mult"] = 0.95
    variant("whiteback_brigandine", "frostbitten_brigandine", "Frostbitten Brigandine", 3, "cursed",
            "Cold went into the plates and stayed. Blows go numb on it, and so does the mending.",
            stats_add={"wound_resist": 10.0, "regen_mult": 0.8}, toll="slow_mending",
            effect_text="Ten more points of wound resistance than any brigandine of its kind.")
    ITEMS["frostbitten_brigandine"]["stats"]["regen_mult"] = 0.8
    variant("wardsilver_ember_charm", "second_mouth", "The Second Mouth", 4, "cursed",
            "A small carved mouth on a thong. Whatever you cast, it says too.",
            stats_add={"ability_damage_mult": 1.12, "reflux_shed_mult": 0.85}, toll="thirsty",
            effect_text="Every ability hits 12% harder, whatever its affinity.")
    ITEMS["second_mouth"]["stats"] = OrderedDict([("ability_damage_mult", 1.12), ("reflux_shed_mult", 0.85)])
    ITEMS["second_mouth"].pop("affinity", None)
    variant("pentad_mote", "gutter_star", "Gutter Star", 5, "cursed",
            "A seven-point flow from a five-point stone. The residue has to go somewhere, and it goes into you.",
            stats_add={"satellite_rate": 2.0, "satellite_reflux_mult": 1.5}, toll="running_hot", value_mult=1.5,
            effect_text="Two stars more flow than it should have.")
    ITEMS["gutter_star"]["stats"]["satellite_reflux_mult"] = 1.5
    variant("veiniron_gauntlets", "grasping_gauntlets", "Grasping Gauntlets", 5, "cursed",
            "They close a little tighter than you told them to, every time.",
            stats_add={"strike_poise_mult": 1.2, "move_speed_mult": 0.95}, toll="reluctant",
            effect_text="Base strikes break poise a fifth faster.")
    ITEMS["grasping_gauntlets"]["stats"]["strike_poise_mult"] = 1.2
    ITEMS["grasping_gauntlets"]["stats"]["move_speed_mult"] = 0.95
    variant("gloamwood_recurve", "widows_draw", "Widow's Draw", 6, "cursed",
            "Strung for someone who never had to look behind her. She was wrong once.",
            stats_mult={"ranged_damage_mult": 1.18}, stats_add={"rear_taken_mult": 1.25}, toll="turned_back",
            effect_text="Shots hit almost a fifth harder than any recurve of its band.")
    ITEMS["widows_draw"]["stats"]["rear_taken_mult"] = 1.25
    variant("still_silk_runners", "unmooring_shoes", "Unmooring Shoes", 7, "cursed",
            "Every step pushes off something that is not quite the ground.",
            stats_add={"move_speed_mult": 0.07, "max_health": round(-8 * B(7), 1)}, toll="leeching",
            effect_text="A tenth faster on your feet.")
    variant("echo_iron_helm", "choir_crown", "Choir Crown", 8, "cursed",
            "A ring of small bells that never ring. You hear them anyway, when you run hot.",
            stats_add={"reflux_pain_shift": 10.0, "projection_hp_bonus": -3.0}, toll="thin_soul",
            effect_text="Reflux pain starts ten points later.")
    variant("heartmetal_heater_shield", "debt_wall", "Debt Wall", 9, "cursed",
            "A door off a debtor's prison, cut down and strapped to an arm. It has held back worse than you.",
            stats_mult={"block": 1.6}, weight_mult=2.0, toll="heavy",
            effect_text="Its guard is more than half again as deep as any heater shield of its band.")
    variant("firstmetal_greatsword", "last_word", "Last Word", 10, "cursed",
            "Whatever it is used on, the argument is over. It keeps the satisfaction for itself.",
            stats_mult={"melee_damage_mult": 1.08}, stats_add={"aura_gain_mult": 0.9}, toll="safe_hands",
            effect_text="It strikes harder than any greatsword of its band.")
    ITEMS["last_word"]["stats"]["aura_gain_mult"] = 0.9
    variant("unwritten_alloy_tide_charm", "unwritten_name", "Unwritten Name", 11, "cursed",
            "A tag with a name on it that slides away when you read it.",
            stats_add={"cost_mult": 0.85, "max_health": round(-10 * B(11), 1)}, toll="leeching",
            effect_text="Every ability costs 15% less essence, whatever its affinity.")
    ITEMS["unwritten_name"]["stats"] = OrderedDict([("cost_mult", 0.85), ("max_health", round(-10 * B(11), 1))])
    ITEMS["unwritten_name"].pop("affinity", None)
    variant("unmade_metal_plate", "unmade_coat", "Unmade Coat", 12, "cursed",
            "Not stitched or forged; it was simply never undone. It keeps you whole, and keeps a little of what you would have become.",
            stats_add={"armour": 3.0, "wound_resist": 4.0, "aura_gain_mult": 0.9}, toll="safe_hands",
            effect_text="More armour and wound resistance than any plate of its band.")
    ITEMS["unmade_coat"]["stats"]["aura_gain_mult"] = 0.9
    # uniques: bend one rule, grow with a stated condition, plateau (design/06 6.4)
    U = "unique"
    variant("gatesteel_gale_charm", "tallymans_thumb", "Tallyman's Thumb", 2, U,
            "A brass thumb-cover off a scale-keeper's hand. Things weigh what it says they weigh.",
            effect="tallymans_thumb", value_mult=12,
            effect_text="Remains you pick up weigh 15% less in your pack (grows to 30%).",
            grows={"condition": "kilograms of remains sold in town", "per": 500, "step": 0.03, "cap": 0.3})
    ITEMS["tallymans_thumb"]["stats"] = OrderedDict()
    ITEMS["tallymans_thumb"].pop("affinity", None)
    variant("steeped_steel_spear", "patient_spear", "The Patient Spear", 3, U,
            "The point never moves until it has to. Then it has already arrived.",
            effect="patient_spear", value_mult=12,
            effect_text="Each half second you stand still adds 5% to your next base strike, up to 50% (grows to 80%).",
            grows={"condition": "kills made without having moved for 2 s", "per": 25, "step": 0.05, "cap": 0.8})
    variant("tetrad_mote", "borrowing_star", "Borrowing Star", 4, U,
            "A satellite that has been spent and spent. It runs on what you have just taken.",
            effect="borrowing_star", value_mult=4,
            effect_text="No flow of its own. Each kill lends you 4 essence a second for 5 seconds; loans stack to five (grows to 8 a second).",
            grows={"condition": "kills made while three or more loans are running", "per": 50, "step": 1.0, "cap": 8.0})
    ITEMS["borrowing_star"]["stats"] = OrderedDict([("satellite_rate", 0.0)])
    variant("drakeskin_cuirass", "drakes_second_skin", "Drake's Second Skin", 5, U,
            "It sloughs. It grows back thicker, and heavier, every time.",
            effect="drakes_second_skin", value_mult=12,
            effect_text="Once a minute, a hit that would leave a lasting wound is taken by the coat instead; it then weighs 2 kg more until you sleep (the minute shrinks to 30 s).",
            grows={"condition": "wounds it has refused", "per": 10, "step": -5, "cap": 30})
    variant("duskmetal_long_flue", "choir_pipe", "Choir Pipe", 6, U,
            "Five reeds bound into one pipe. Whatever you are running hot on, it sings.",
            effect="choir_pipe", value_mult=12,
            effect_text="Each shot vents 3 from every affinity you hold and does 40% more for each one that was above 50 (grows to 60%).",
            grows={"condition": "affinities kept above 80 without locking, a minute at a time", "per": 20, "step": 0.05, "cap": 0.6})
    variant("still_silk_hood", "still_mask", "The Still Mask", 7, U,
            "A face with no expression and no breath. Things looking for you look past it.",
            effect="still_mask", value_mult=12,
            effect_text="After 2 seconds without moving, archers and casters lose their aim on you (the wait shrinks to 1 s).",
            grows={"condition": "shots that lost their aim on you", "per": 50, "step": -0.2, "cap": 1.0})
    variant("echo_iron_cooling_coil", "echo_coin", "Echo Coin", 8, U,
            "A coin that is heads in one world and tails in the other.",
            effect="echo_coin", value_mult=12,
            effect_text="Every tenth base strike lands twice; the echo does half (grows to every seventh, at 70%).",
            grows={"condition": "strikes echoed", "per": 500, "step": 1, "cap": 7})
    ITEMS["echo_coin"]["stats"] = OrderedDict()
    variant("heartmetal_sword", "heartmetal_tithe", "Heartmetal Tithe", 9, U,
            "It does not cut so much as collect. It is never in a hurry.",
            effect="heartmetal_tithe", value_mult=12,
            effect_text="A base strike also takes 1% of what the target has left, never more than the strike itself (grows to 2%).",
            grows={"condition": "deviants killed with it", "per": 3, "step": 0.0025, "cap": 0.02})
    variant("firstmetal_tablet", "first_word", "First Word", 10, U,
            "A tablet with one word on it. You will not be able to read it until you have said it.",
            effect="first_word", value_mult=12,
            effect_text="The first skill you cast in each fight costs no essence and leaves no reflux (grows to the first two).",
            grows={"condition": "fights opened that way and won", "per": 200, "step": 1, "cap": 2})
    variant("unwritten_alloy_storm_charm", "unwritten_page", "Unwritten Page", 11, U,
            "Blank. Hold it beside something else and it remembers what it saw.",
            effect="unwritten_page", value_mult=12,
            effect_text="Copies the stat line of the other trinket you wear at half strength (grows to full).",
            grows={"condition": "different trinkets worn beside it for a whole delve", "per": 3, "step": 0.1, "cap": 1.0})
    ITEMS["unwritten_page"]["stats"] = OrderedDict()
    ITEMS["unwritten_page"].pop("affinity", None)
    variant("unmade_metal_maul", "the_unmade_thing", "The Unmade Thing", 12, U,
            "It is shaped like whatever you expect. Nobody has seen it twice the same.",
            effect="the_unmade_thing", value_mult=12,
            effect_text="Its family is that of the last weapon you held in your main hand, and its numbers are that family's at its band (each family mastered adds 2% damage, to 14%).",
            grows={"condition": "families mastered (100 kills with each)", "per": 1, "step": 0.02, "cap": 0.14})
    # storage rings [C: storage rings exist; the name is ours]: they take the back slot's place
    for b, cap in ((4, 1.5), (6, 1.5), (8, 1.5), (10, 1.5)):
        frame = ITEMS[slug(f"{BAND_INFO[b]['leather']} Frame")]
        name = {4: "Hollow Band", 6: "Deep Hollow Band", 8: "Echoing Hollow Band", 10: "First Hollow Band"}[b]
        add(slug(name), base_item(name, "back", "gear", "storage", b, 0.05, nice(trip(b) * 8),
                                  "A ring with room inside it. You reach in with your attention, not your hand, and what is stowed deep stays put. It takes the place of whatever you carried on your back, and nothing in it can be felt from outside.",
                                  1, rarity="fine", stats={"carry_capacity": round(frame["stats"]["carry_capacity"] * cap, 1)},
                                  line="hollow_band", effect="masks_aura",
                                  effect_text="Hides the aura of what it holds (design/10 'Loud' rule).", source=["auction", "drop"]))


# ---------- ammunition ----------
def make_ammo(b):
    m = mat_ids(b)
    metal = BAND_INFO[b]["metal"]
    mult = round(1 + 0.02 * (b - 1), 2)

    def am(iid, name, kind, count, rec, inputs, makes, w, desc, line, **extra):
        val, fee = derived_item_value(inputs, 0.2, makes, 1.25)
        add(iid, base_item(name, "", "ammo", "ammo", b, kg(w * W(b)), val, desc, 10, ammo_kind=kind, count=count,
                           recover=rec, ammo_damage_mult=mult, line=line, source=["shop", "craft", "drop"],
                           recipe=recipe("bowyer", b, inputs, fee, makes), **extra))
    if b > 1:  # band 1 has design/06's arrows, bolts and lead shot
        am(slug(f"{metal} Tipped Arrows"), f"{metal}-Tipped Arrows", "arrow", 20, 0.5, {m["stave"]: 1, m["wire"]: 1}, 3, 0.8,
           f"Twenty arrows with {metal.lower()} heads. About half come back.", "arrows")
        am(slug(f"{metal} Bolts"), f"{metal} Bolts", "bolt", 12, 0.6, {m["stave"]: 1, m["bar"]: 1}, 3, 1.0,
           f"Twelve short bolts, {metal.lower()} to the shoulder. Most can be dug out.", "bolts")
        am(slug(f"{metal} Shot"), f"{metal} Shot", "shot", 30, 0.0, {m["bar"]: 1}, 2, 1.5,
           f"Thirty cast {metal.lower()} bullets for a sling. Gone once thrown.", "shot")
    if b in (4, 7, 10):
        am(slug(f"{metal} Barbed Arrows"), f"{metal} Barbed Arrows", "arrow_barbed", 12, 0.0, {m["stave"]: 1, m["wire"]: 2}, 3, 0.6,
           "Twelve barbed arrows. They do not come out the way they went in, so they do not come back.", "barbed_arrows",
           on_hit={"status": "bleeding", "stacks": 1})
    if b in (1, 4, 7, 10):
        mm = mat_ids(b)
        am("bodkin_arrows" if b == 1 else slug(f"{metal} Bodkins"), "Bodkin Arrows" if b == 1 else f"{metal} Bodkins",
           "arrow_bodkin", 12, 0.4, {mm["stave"]: 1, mm["bar"]: 1}, 3, 0.7,
           "Twelve square-headed arrows for armour. Front armour and shields count half against them.", "bodkins",
           on_hit={"front_armour_ignore": 0.5})
        am("blunt_bolts" if b == 1 else slug(f"{metal} Blunt Bolts"), "Blunt Bolts" if b == 1 else f"{metal} Blunt Bolts",
           "bolt_blunt", 12, 0.8, {mm["stave"]: 1, mm["leather"]: 1}, 3, 1.0,
           "Twelve bolts with heavy blunt heads. They break poise, not skin, and nearly all come back.", "blunt_bolts",
           on_hit={"poise_add": 30})


# ---------- alchemy ----------
def consumable(b, iid, name, inputs, makes, use, desc, line, station="alchemist", w=0.3, stars=None, source=None, factor=1.25, fee_frac=0.2):
    val, fee = derived_item_value(inputs, fee_frac, makes, factor)
    add(iid, base_item(name, "", "consumable", "consumable", b, kg(w), val, desc, 10, use=use, line=line,
                       source=source or ["craft", "shop"], recipe=recipe(station, b, inputs, fee, makes, stars=stars)))


GRADE_PREFIX = {1: "", 3: "Clouded ", 5: "Clear ", 7: "Bright ", 9: "Singing ", 11: "Unblemished "}


def make_alchemy(b):
    m = mat_ids(b)
    word = BAND_INFO[b]["word"]
    fl = FLORA[b] if b > 1 else ("Lockweed", "Slate Fern", "Grey Lichen", "Barrow Sloe")
    bp = lambda base: f"{base}" if b == 1 else f"{word} {base}"  # noqa: E731
    k = (b - 1) // 2
    if b > 1:
        consumable(b, slug(f"{fl[0]} Poultice"), f"{fl[0]} Poultice", {m["knit"]: 1, m["cloth"]: 1}, 2,
                   {"effect": "poultice", "heal_frac": round(0.2 + 0.01 * (b - 1), 2), "over_s": 10.0, "out_of_combat": True,
                    "regen_mult": 1.5, "for_s": 300.0, "aura_penalty": 0.0},
                   f"{fl[0]} bound in cloth. Out of a fight it returns a fifth of your health over ten seconds and speeds natural healing for five minutes. Ordinary medicine; the star does not mind.",
                   "poultice", station="camp")
    sink = round(12 * B(b))
    consumable(b, "knitting_salve" if b == 1 else slug(f"{fl[0]} Salve"), "Knitting Salve" if b == 1 else f"{fl[0]} Salve",
               {m["knit"]: 2, m["salt"]: 1}, 1,
               {"effect": "mend_wound", "sink_points": float(sink), "target": "oldest", "aura_penalty": 0.0},
               f"Rubbed into your oldest lasting wound, it does {sink} points of the healing that wound is waiting for. Slower than the bonesetter, and you can carry it.",
               "wound_salve")
    if b in (1, 4, 7, 10):
        consumable(b, "regrowth_draught" if b == 1 else slug(f"{word} Regrowth Draught"), bp("Regrowth Draught"),
                   {m["knit"]: 3, m["fruit"]: 1, m["bone"]: 1}, 1,
                   {"effect": "regrow_arm", "heal_points": round(25 * B(b), 1), "out_of_combat": True, "aura_penalty": 0.0},
                   "Drunk in a safe place, it grows back a lost arm over the night. It itches for a week.", "regrowth", w=0.5)
    if b in (2, 4, 6, 8, 10):
        consumable(b, slug(f"{word} Clotting Powder"), f"{word} Clotting Powder", {m["knit"]: 1, m["bone"]: 1}, 3,
                   {"effect": "clot", "clears": ["bleeding"], "next_wound_sink_mult": 0.75, "aura_penalty": 0.0},
                   "Thrown into a wound mid-fight: bleeding stops, and the next wound you take is a quarter shallower.", "clotting", w=0.1)
    if b > 1:
        consumable(b, slug(f"{fl[1]} Draught"), f"{fl[1]} Draught", {m["bitter"]: 2, m["salt"]: 1}, 1,
                   {"effect": "essence", "amount": float(30 * b), "reflux_all": 15.0, "aura_penalty": 0.1},
                   f"{30 * b} essence, now. It leaves 15 reflux on every affinity, and the delve teaches you a little less.",
                   "essence_draught", w=0.4)
        amt = float(min(60, 30 + 3 * (b - 1)))
        allaff = b >= 6
        consumable(b, slug(f"{fl[2]} Paste"), f"{fl[2]} Paste", {m["cold"]: 2, m["salt"]: 1}, 1,
                   {"effect": "shed_reflux", "amount": amt, "all_affinities": allaff, "aura_penalty": 0.1},
                   f"Cold, grey and smelling of pennies. Takes {int(amt)} reflux off {'every affinity' if allaff else 'your hottest affinity'}. The delve teaches you a little less for it.",
                   "cooling_paste")
    if b in (3, 5, 7, 9, 11):
        sec = 60 + 10 * k
        consumable(b, slug(f"{word} Numbing Salt"), f"{word} Numbing Salt", {m["cold"]: 1, m["bitter"]: 1}, 2,
                   {"effect": "ignore_wounds", "for_s": float(sec), "wound_pool_add_frac": 0.1, "aura_penalty": 0.1},
                   f"For {sec} seconds your wounds cost you nothing. Then each one is a tenth deeper, and the delve teaches you a little less.",
                   "numbing_salt", w=0.1)
    if b in (1, 3, 5, 7, 9):
        pct = 10 + 2 * k
        consumable(b, "iron_tonic" if b == 1 else slug(f"{word} Iron Tonic"), bp("Iron Tonic"), {m["bitter"]: 1, m["bone"]: 1, m["fruit"]: 1}, 2,
                   {"effect": "tonic", "stat": "melee_damage_mult", "value": round(1 + pct / 100, 2), "for_s": 120.0,
                    "crash_value": 0.9, "crash_s": 120.0, "aura_penalty": 0.1},
                   f"An alchemist's strength tonic. Two minutes of strikes {pct}% harder, then two minutes of strikes a tenth weaker. The delve teaches you a little less.",
                   "iron_tonic")
    if b in (2, 4, 6, 8, 10):
        consumable(b, slug(f"{word} Steadying Tonic"), f"{word} Steadying Tonic", {m["bone"]: 1, m["knit"]: 1}, 2,
                   {"effect": "tonic", "stat": "poise", "value": 25.0 + 5 * k, "for_s": 120.0, "crash_value": -25.0,
                    "crash_s": 60.0, "aura_penalty": 0.1},
                   "Two minutes of steadier feet (more poise), then a minute of wobbling. The delve teaches you a little less.",
                   "steadying_tonic")
    if b in (1, 2, 4, 6, 8, 10):
        consumable(b, "yard_liniment" if b == 1 else slug(f"{word} Yard Liniment"), bp("Yard Liniment"),
                   {m["knit"]: 1, m["cold"]: 1, m["cloth"]: 1}, 2,
                   {"effect": "temper_aid", "sessions": 1, "strain_mult": 0.7, "progress_mult": 0.9},
                   "Rubbed in before a tempering session: the strain it leaves is smaller, and so is what you learn.",
                   "yard_liniment")
    if b <= 10:
        frac = 0.08
        consumable(b, "pale_tincture" if b == 1 else slug(f"{word} Pale Tincture"), bp("Pale Tincture"),
                   {m["fruit"]: 3, m["salt"]: 2, m["elite"]: 1}, 1,
                   {"effect": "blank_aura", "aura_frac": frac, "talent_wear": 1, "ascension_quality": -0.05, "max_per_star": 5},
                   "An ascension aid. It pours blank growth into your newest star. The star fills; what it fills with is nobody in particular. Too many and the talent itself starts to wear.",
                   "pale_tincture", w=0.2, stars=max(1, b - 1), source=["craft", "shop_rotation"])
    if b in (3, 6, 9):
        nm = {3: "Unbroken Seed", 6: "Unbroken Root", 9: "Unbroken Crown"}[b]
        add(slug(nm), base_item(nm, "", "consumable", "consumable", b, 0.1, nice(trip(b) * 100),
                                "A true ascension elixir, of no known origin. It fills the newest star and makes what comes next a little more yours. Worth killing for, and people have.",
                                1, use={"effect": "true_ascension", "aura_frac": 0.5, "ascension_quality": 0.2, "placeholder": True},
                                line="true_elixir", placeholder=True, source=["auction", "feat"]))
    if b in (2, 5, 8):
        nm = f"{word} Blank Draught"
        add(slug(nm), base_item(nm, "", "consumable", "consumable", b, 0.3, nice(trip(b) * 3),
                                "A soul elixir from a clinic. It patches soul damage with blank tissue. For small cracks, nobody notices; for big ones, slowly, you become someone else.",
                                5, use={"effect": "soul_patch", "placeholder": True}, line="soul_draught", placeholder=True,
                                source=["clinic"]))
    if b == 5:
        add("root_cut_elixir", base_item("Root-Cut Elixir", "", "consumable", "consumable", 5, 0.3, nice(trip(5) * 20),
                                          "It severs the path you climbed by. Every star goes, and you may climb again by any way you like. Severed powerhouses are a known type; most do not come back up.",
                                          1, use={"effect": "sever_path", "placeholder": True}, line="severing", placeholder=True,
                                          source=["clinic", "auction"]))
    if b in (1, 3, 5, 7, 9, 11):
        consumable(b, "bleeding_oil" if b == 1 else slug(f"{word} Bleeding Oil"), bp("Bleeding Oil"), {m["bone"]: 1, m["bitter"]: 1}, 2,
                   {"effect": "coat", "strikes": 20 + 2 * k, "on_hit": {"status": "bleeding", "stacks": 1}},
                   f"Wiped on an edge: for {20 + 2 * k} base strikes each hit opens one more bleeding stack.", "bleeding_oil", w=0.2)
    if b in (2, 4, 6, 8, 10, 12):
        dps = round(6 * B(b) * G(b), 1)
        consumable(b, slug(f"{word} Sap Venom"), f"{word} Sap Venom", {m["bitter"]: 2, m["cold"]: 1}, 2,
                   {"effect": "coat", "strikes": 15, "on_hit": {"status": "venom", "dps": dps, "for_s": 5.0}},
                   f"For 15 base strikes each hit poisons for {dps} a second over five seconds. Poison you laid pays your talent like any other harm.",
                   "sap_venom", w=0.2)
    if b in (1, 4, 7, 10):
        consumable(b, "lead_lacquer" if b == 1 else slug(f"{word} Lead Lacquer"), bp("Lead Lacquer"), {m["bar"]: 1, m["salt"]: 1}, 3,
                   {"effect": "coat", "strikes": 20, "strike_poise_mult": 1.5},
                   "A heavy lacquer for a weapon's head. For 20 base strikes they break poise half again as fast.", "lead_lacquer", w=0.3)
    if b in (1, 4, 7, 10):
        consumable(b, "smoke_pot" if b == 1 else slug(f"{word} Smoke Pot"), bp("Smoke Pot"), {m["cold"]: 1, m["cloth"]: 1}, 2,
                   {"effect": "throw", "what": "smoke", "radius": 3.0, "for_s": 4.0 + k},
                   "Thrown: a bank of smoke three metres across. Nothing shoots through it.", "smoke_pot", w=0.5)
    if b in (2, 5, 8):
        consumable(b, slug(f"{word} Caltrops"), f"{word} Caltrops", {m["bar"]: 1}, 3,
                   {"effect": "throw", "what": "caltrops", "radius": 3.0, "for_s": 8.0, "slow": 0.4},
                   "Thrown: a spray of spikes. Anything walking through them goes four-tenths slower.", "caltrops", w=0.5)
    if b in (3, 6, 9):
        consumable(b, slug(f"{word} Flash Powder"), f"{word} Flash Powder", {m["salt"]: 1, m["bitter"]: 1}, 2,
                   {"effect": "throw", "what": "flash", "radius": 4.0, "interrupts": True},
                   "Thrown: a white flash. Every wind-up within four metres is broken.", "flash_powder", w=0.2)
    if b in (1, 3, 5, 7, 9):
        consumable(b, "tether_incense" if b == 1 else slug(f"{word} Tether Incense"), bp("Tether Incense"), {m["salt"]: 1, m["cold"]: 1}, 2,
                   {"effect": "nether", "leash_bonus": 3.0 + k, "projections": 1},
                   f"Burned before you sit: your next projection strays {3 + k} metres further from the body.", "tether_incense", w=0.1)
    if b in (2, 4, 6, 8, 10):
        consumable(b, slug(f"{word} Second-Skin Wax"), f"{word} Second-Skin Wax", {m["salt"]: 1, m["knit"]: 1}, 2,
                   {"effect": "nether", "projection_hp_bonus": 3.0 + k, "projections": 1},
                   f"Rubbed on the temples: your next projection has {3 + k} more life.", "second_skin_wax", w=0.1)
    if b in (1, 3, 5, 7, 9, 11):
        consumable(b, "binding_salts" if b == 1 else slug(f"{word} Binding Salts"), bp("Binding Salts"), {m["salt"]: 2}, 1,
                   {"effect": "bind_aid", "success_add": 0.05, "binds": 1},
                   "Scattered in a circle before a binding: the next binding of a construct is a little likelier to hold.", "binding_salts", w=0.2)
    if b in (1, 4, 7, 10):
        consumable(b, "trail_ration" if b == 1 else slug(f"{word} Trail Ration"), bp("Trail Ration"), {m["fruit"]: 1, m["knit"]: 1}, 4,
                   {"effect": "food", "regen_mult": 1.25, "for_hours": 1.0, "aura_penalty": 0.0},
                   "Hard bread, dried fruit and something salted. For an hour of the clock natural healing runs a quarter faster.",
                   "trail_ration", station="camp", w=0.4)
    if b in (3, 6, 9):
        consumable(b, slug(f"{word} Short-Night Pill"), f"{word} Short-Night Pill", {m["bitter"]: 1, m["cold"]: 1, m["fruit"]: 1}, 3,
                   {"effect": "short_night", "rest_hours": 1.0, "placeholder": True},
                   "A night's sleep in an hour. The body is rested; the mind will mention it later.", "short_night", w=0.05)


# ---------- skill consumables (empower or fuel a skill) ----------
SKILL_CONS = {
    "water": ("Brine Charge", "Your next three water skills shove {a}% further.", lambda k: {"effect": "empower", "affinity": "water", "casts": 3, "shove_mult": round(1.3 + 0.1 * k, 2)}, lambda k: int(30 + 10 * k)),
    "fire": ("Pitch Wick", "For ten seconds your Heat counts as {a} reflux higher than it is, without the reflux.", lambda k: {"effect": "empower", "affinity": "fire", "for_s": 10.0, "heat_reflux_add": 20.0 + 5 * k}, lambda k: int(20 + 5 * k)),
    "earth": ("Mason's Grit", "Your next two standing stones have {a}% more life and stand half as long again.", lambda k: {"effect": "empower", "affinity": "earth", "stones": 2, "stone_hp_mult": round(1.5 + 0.1 * k, 2), "stone_life_mult": 1.5}, lambda k: int(50 + 10 * k)),
    "wind": ("Gale Quill", "{a} Slipstream pips at once.", lambda k: {"effect": "empower", "affinity": "wind", "pips": 4 + k}, lambda k: int(4 + k)),
    "lightning": ("Charged Filament", "Your next three lightning hits leave {a} marks instead of one.", lambda k: {"effect": "empower", "affinity": "lightning", "casts": 3, "marks_per_hit": 2 if k < 3 else 3}, lambda k: 2 if k < 3 else 3),
}


def make_skill_consumables(b):
    if b not in SETTLED_GRADES:
        return
    k = SETTLED_GRADES.index(b)
    m = mat_ids(b)
    pre = GRADE_PREFIX[b]
    for aff, (base, text, use_fn, amt_fn) in SKILL_CONS.items():
        name = f"{pre}{base}"
        use = use_fn(k)
        use["aura_penalty"] = 0.05
        val, fee = derived_item_value({settled_id(aff, b): 1, m["salt"]: 1}, 0.2, 2, 1.25)
        add(slug(name), base_item(name, "", "consumable", "skill_consumable", b, 0.1, val,
                                  f"{text.format(a=amt_fn(k))} Only for someone with the {aff} affinity. The delve teaches you a little less.",
                                  10, affinity=aff, use=use, line=f"empower_{aff}", source=["craft", "shop"],
                                  recipe=recipe("alchemist", b, {settled_id(aff, b): 1, m["salt"]: 1}, fee, 2)))
    name = f"{BAND_INFO[b]['grade_word']} Ether Sliver"
    cover = 12 * b
    val, fee = derived_item_value({m["salt"]: 2}, 0.2, 1, 1.25)
    add(slug(name), base_item(name, "", "consumable", "skill_consumable", b, 0.05, val,
                              f"A sliver of settled ether that burns in place of your stars: your next skill's essence cost, up to {cover}, is paid from it. Its reflux is still yours. The delve teaches you a little less.",
                              10, use={"effect": "pay_cost", "up_to": float(cover), "aura_penalty": 0.05}, line="ether_sliver",
                              source=["craft", "shop"], recipe=recipe("alchemist", b, {m["salt"]: 2}, fee, 1)))


# ---------- spoils, catalysts, keys, spirit imprints, concord stones ----------
def make_misc(b):
    word = BAND_INFO[b]["word"]
    for iid, nm, kgw, val, desc in (("strongbox", "Strongbox", 2.5, 2000, "Passage spoils, locked and heavy. The counting-house in town opens it and pays."),
                                    ("relics", "Relic Case", 1.0, 500, "Passage spoils: odd small things the passage gave up. They sell."),
                                    ("salvage", "Salvage", 0.5, 100, "Passage spoils: scrap worth having. It sells.")):
        add(f"spoils_{iid}_b{b}", base_item(f"{word} {nm}", "", "spoils", "spoils", b, kg(kgw * W(b)), nice(val * V(b)), desc,
                                            1 if kgw > 1 else 5, line=f"spoils_{iid}", source=["exit"]))
    cat = {2: ("Reeking Standard", "remnant"), 3: ("Frostbound Tally-Stick", "remnant"), 4: ("Spindle Shroud", "spirit"),
           5: ("Drake-Gnawed Shield", "eidolon"), 6: ("Lampless Lantern", "eidolon"), 7: ("Silenced Bell", "asura"),
           8: ("Doubled Skull", "asura"), 9: ("Giant's Last Tooth", "asura"), 10: ("First-Blood Stone", "asura"),
           11: ("Unwritten Stain", "asura"), 12: ("Unmade Wound", "asura")}[b]
    add(slug(cat[0]), base_item(cat[0], "", "catalyst", "catalyst", b, kg(1.0 * W(b)), nice(800 * V(b)),
                                f"Soaked through at the middle of a slaughter. Carry it while you project: what waits is more likely to be a {cat[1]}.",
                                1, catalyst={"tier_chance_add": 0.15, "tier": cat[1]}, line="catalyst", source=["drop"]))
    add(f"key_writ_b{b}", base_item(f"{word} Passage Writ", "", "key", "key", b, 0.1, 0,
                                    f"Placeholder: the entry writ for an owned passage rated for {BAND_INFO[b]['label']}. Bought at that region's ticket hall.",
                                    1, sellable=False, placeholder=True, source=["shop", "quest"]))
    if b in (4, 6, 8, 10):
        imp = {4: ("The Long Count", "Spoken aloud: for 8 seconds every hit on you is written down instead of felt; then all of it arrives at once, halved."),
               6: ("Bargain Struck", "Spoken aloud: a fifth of your health is gone until the fight ends, and every hit you deal is 30% harder until then."),
               8: ("Toll Bell", "Spoken aloud: every enemy within 10 m loses half its poise; the price is a lasting wound on you."),
               10: ("Unwitnessed", "Spoken aloud: for 4 seconds nothing can see you; the price is a night's sleep that heals nothing.")}[b]
        add(slug(f"imprint {imp[0]}"), base_item(f"Spirit Imprint: {imp[0]}", "", "spirit_imprint", "scroll", b, 0.1, nice(trip(b) * 20),
                                                 f"{imp[1]} A spirit ability: it always has a price, and holding one slows the next star.",
                                                 1, placeholder=True, aura_compression=0.33, source=["auction", "feat"]))
    if b in (5, 8, 11):
        nm, binds = {5: ("Lesser Concord Stone", 3), 8: ("Concord Stone", 3), 11: ("Greater Concord Stone", 4)}[b]
        add(slug(nm), base_item(nm, "", "binding", "binding", b, 0.2, nice(trip(b) * 50),
                                f"Placeholder (sets are parked): fuses {binds} items into a set that shares a bonus. Needs a master artificer, and does not always take.",
                                1, binds=binds, placeholder=True, source=["auction", "feat"]))


# --------------------------------------------------------------------------------------------
def main():
    v2, live = build_band1()
    pieces = wardrobe_looks()
    build_band1_additions()
    band1_recipes()
    band1_gear_recipes()
    make_alchemy(1)
    make_skill_consumables(1)
    make_ammo(1)
    # band-1 recipes for design/06 consumables and ammo whose values are fixed
    m1 = mat_ids(1)
    for iid, inputs in (("field_dressing", {"linen_bolt": 1}), ("bitter_draught", {"slate_fern_root": 2, "flux_salt": 1}),
                        ("cooling_paste", {"grey_lichen": 2, "flux_salt": 1}), ("numbing_salt", {"grey_lichen": 1, "slate_fern_root": 1}),
                        ("arrow_bundle", {"heartwood_stave": 1, "binding_wire": 1}), ("barbed_arrows", {"heartwood_stave": 1, "binding_wire": 2}),
                        ("bolt_case", {"heartwood_stave": 1, "steel_billet": 1}), ("lead_shot", {"steel_billet": 1})):
        it = ITEMS[iid]
        station = "camp" if iid == "field_dressing" else ("bowyer" if it["kind"] == "ammo" else "alchemist")
        it["recipe"] = fixed_value_recipe(station, 1, inputs, it["value"], 1.25, stars=1)
        it.setdefault("source", ["shop", "craft"])
    for b in range(2, BAND_MAX + 1):
        build_materials(b)
        if b <= 10:
            for spec in LINES:
                make_line_item(spec, b)
            make_worn_lines(b)
        else:
            make_beyond_lines(b)
        make_alchemy(b)
        make_skill_consumables(b)
        make_ammo(b)
        make_misc(b)
    runes = v2["runes"]
    for b in range(2, 11):
        make_runed(b, runes)
    for iid, it in ITEMS.items():  # band-1 runed items: recipe from base + ink
        if it.get("rarity") == "runed" and it["band"] == 1 and "base" in it and "recipe" not in it:
            base = ITEMS[it["base"]]
            it["recipe"] = recipe("runesetter", 1, {it["base"]: 1, "rune_ink": 1}, 0.6 * (it["value"] - base["value"]), 1, stars=1,
                                  note="fails 10% of the time: ink and fee lost, item kept (design/06 8.5)")
    make_specials()
    # defaults
    for iid, it in ITEMS.items():
        if "source" not in it:
            k = it["kind"]
            it["source"] = {"gear": ["drop"], "remains": ["drop"], "trade": ["drop"], "material": ["drop"],
                            "scroll": ["shop", "drop"], "spoils": ["exit"], "catalyst": ["drop"], "consumable": ["shop"],
                            "ammo": ["shop", "drop"], "reagent": ["gather"]}.get(k, ["drop"])
        # keep 'desc' last for readability
        d = it.pop("desc")
        it["desc"] = d

    # recipes view
    recipes = []
    for iid, it in ITEMS.items():
        if "recipe" in it:
            r = OrderedDict([("id", f"r_{iid}"), ("output", iid), ("band", it["band"])])
            r.update(it["recipe"])
            recipes.append(r)
    station_order = ["camp", "forge", "leatherworks", "bowyer", "loom", "alchemist", "runesetter"]
    recipes.sort(key=lambda r: (station_order.index(r["station"]), r["band"], r["output"]))

    bands = OrderedDict()
    for b in range(1, BAND_MAX + 1):
        info = BAND_INFO[b]
        bands[str(b)] = OrderedDict([
            ("label", info["label"]), ("where", info["where"]), ("constructs", info["construct"]),
            ("gear_factor", r3(G(b))), ("weight_factor", r3(W(b))), ("value_factor", int(V(b))),
            ("body_health", r3(B(b))), ("body_strike", r3(S(b))), ("essence_tanks", b), ("satellite_rate", float(b)),
            ("worn_allowance_kg", RULES["worn_free_kg"] + RULES["worn_per_star_kg"] * (b - 1)),
            ("trip_income", int(trip(b))), ("station_grade", grade(b)),
            ("metal", info["metal"]), ("leather", info["leather"]), ("wood", info["wood"]), ("cloth", info["cloth"]),
        ])
    out = OrderedDict()
    out["_note"] = ("DRAFT - not loaded by the game. The full-game item catalogue of design/10-item-catalogue-v0.md, generated by "
                    "tools/items/build_items_draft.py (edit the tables there, not this file) and checked by tools/items/validate_items.py. "
                    "Same schema as game/data/items.json (id -> {name, slot, weight, value, stats, desc, ...}); new fields are documented in "
                    "design/10 section 13: kind, category, band, rarity, stack, line, material, look, source, recipe, use, role, affinity, "
                    "placeholder, sellable, teaches_technique. Band 1 is the approved design/06 catalogue (items-v2.json) merged with the live "
                    "ids. Every name and description is original to this project [MODEL].")
    out["base_carry_capacity"] = live["base_carry_capacity"]
    out["starting_equipped"] = v2["starting_equipped"]
    out["starting_bag"] = v2["starting_bag"]
    out["bands"] = bands
    out["rules"] = OrderedDict([
        ("_note", "Proposed rules this catalogue assumes (design/10). None is in the game."),
        ("factors", RULES),
        ("sell_factor_by_kind", OrderedDict([("gear", 0.5), ("consumable", 0.5), ("ammo", 0.5), ("scroll", 0.5), ("manual", 0.5),
                                             ("spirit_imprint", 0.5), ("binding", 0.5), ("material", 1.0), ("reagent", 1.0),
                                             ("remains", 1.0), ("trade", 1.0), ("proof", 1.0), ("spoils", 1.0), ("catalyst", 1.0),
                                             ("key", 0.0), ("quest", 0.0)])),
        ("loud", OrderedDict([("free_bands_above_stars", 2),
                              ("_note", "An item more than two bands above your stars is Loud: its effect line, rune and toll are dormant and enemies of its band notice you from 50% further. Base numbers (and satellites, by Brent's ruling) always work.")])),
        ("caps_per_star", OrderedDict([("armour_cap_base", 30.0), ("armour_cap_per_star", 2.0), ("block_cap_scales_with", "body_health"),
                                       ("_note", "Every other design/06 cap stays as it is.")])),
        ("rune_cap", RUNE_CAP),
        ("crafting", OrderedDict([("gear_inputs_target", 0.45), ("gear_cost_target", 0.75), ("alchemy_value_factor", 1.25),
                                  ("material_value_factor", 0.95), ("runesetter_fee_of_added_value", 0.6), ("rune_fail_chance", 0.1)])),
        ("tolls", v2["tolls"]),
        ("runes", v2["runes"]),
        ("families", v2["families"]),
    ])
    out["items"] = ITEMS
    out["shop"] = v2["shop"]
    out["spoils"] = live["spoils"]
    OUT_ITEMS.write_text(json.dumps(out, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")

    stations = OrderedDict([
        ("camp", {"name": "Camp", "where": "anywhere you can sit; no fee is paid to anyone, the fee is the time", "grades": {"0": "anywhere"}}),
        ("forge", {"name": "Forge", "what": "bars, wire, metal weapons, heavy armour, metal shields, flues, thrown weapons"}),
        ("leatherworks", {"name": "Leatherworks", "what": "leather, medium armour, slings, belts, frames"}),
        ("bowyer", {"name": "Bowyer-Fletcher", "what": "staves, bows, crossbows, wooden shields, ammunition"}),
        ("loom", {"name": "Loom", "what": "cloth, light armour"}),
        ("alchemist", {"name": "Alchemist's Bench", "what": "rune ink, potions, salves, tonics, poisons, skill consumables, sumps"}),
        ("runesetter", {"name": "Runesetter", "what": "runes on Fine gear, charms, talismans, coils, focus tablets (design/06 8.5)"}),
    ])
    grades = OrderedDict([("1", "Tithebarrow: the Ninth and Passage Row (design/07)"), ("2", "Winchgate (design/07 region 3)"),
                          ("3", "a city of the deep Understeps (not designed)"), ("4", "not designed"), ("5", "not designed"),
                          ("6", "not designed")])
    for k, s in stations.items():
        if k != "camp":
            s["grades"] = grades
    rout = OrderedDict([
        ("_note", "DRAFT - not loaded. Every recipe in items-full-v0.json, grouped by station (generated from the items' own 'recipe' fields; the item is the source of truth). grade: the station grade needed (bands 1-2 grade 1, 3-4 grade 2, ...). stars: the stars you need to work the materials yourself. fee: dollars paid for the station (and, for Fine work, the master's time). makes: how many come out. hours: world-clock hours. A recipe's output never sells for more than its inputs plus fee (design/10 section 12)."),
        ("stations", stations),
        ("recipes", recipes),
    ])
    OUT_RECIPES.write_text(json.dumps(rout, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"wrote {len(ITEMS)} items, {len(recipes)} recipes")
    bad_looks = [i for i, it in ITEMS.items() if "look" in it and it["look"] not in pieces]
    if bad_looks:
        print("unknown wardrobe pieces:", bad_looks)


if __name__ == "__main__":
    main()
