#!/usr/bin/env python3
"""Write game/data/constructs.json: the construct tiers, the words constructs carry, and the wild numbers.

Brent 2026-11-04 (design/14 section 14): "There should be vestiges for every rune word we have....and so
on up the complexity ladder." His answers:
- a VESTIGE carries one rune ("a vestige of Flood"): one for every rune in runes.json (base and universal),
  made here from the rune list, never authored by hand;
- higher tiers carry words of more runes: a REMNANT a two-rune word, a SPIRIT three, an EIDOLON four, an
  ASURA five. They are authored below (WORDS): a set per affinity and universal ones. The six hand-made
  concepts of 2026-09 (Acceleration, Piercing, Compression, Tension, Reach, Stillness) are the first
  universal remnants, spelled from real runes, and keep their ids. Order matters: Motion + Stillness is
  Friction, Stillness + Motion is Lurch (design/13 section 1);
- a word of universal runes fits any skill; one with an affinity rune fits only where that rune could be
  set (the game's own rule: a base rune of an affinity the character holds - Player.can_use_rune).
This is also his framing of 2026-10-21 (design/13): "The runes are like the letters of those concepts."

The word NAMES and MEANINGS are ours [MODEL]: original inventions, never book text or canon names.

Run after runes.json changes (tools/runes/export_runes_json.py runs it at its end):
    python -P -E tools/runes/construct_words.py
then tools/runes/rune_sources.py (subduing a construct reveals its word's runes first).
Every number here is [MODEL].
"""
import json
from collections import OrderedDict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RUNES = ROOT / "game/data/runes.json"
OUT = ROOT / "game/data/constructs.json"

# Canon order and tier-to-stage mapping (design/01 LAW 4, LAW 5): stage 0 -> 1 needs a vestige ...
TIERS = ["vestige", "remnant", "spirit", "eidolon", "asura"]
# Brent 2026-11-04: how many runes a word of each tier carries.
TIER_RUNES = OrderedDict([("vestige", 1), ("remnant", 2), ("spirit", 3), ("eidolon", 4), ("asura", 5)])

# How each tier behaves when met wild in the Netherecho (hp, damage per hit to the projection, speed,
# attack timing, size) [MODEL]. Nothing spawns an eidolon or an asura yet (wild sites roll vestiges and
# remnants; zones place vestiges, remnants and spirits), so they have no wild numbers: add them here
# when something does.
WILD = OrderedDict([
    ("vestige", OrderedDict([("hp", 90.0), ("damage", 4.0), ("speed", 3.0), ("cooldown", 1.4), ("windup", 0.5),
                             ("reach", 1.6), ("height", 0.9), ("radius", 0.45)])),
    ("remnant", OrderedDict([("hp", 300.0), ("damage", 7.0), ("speed", 3.5), ("cooldown", 1.2), ("windup", 0.45),
                             ("reach", 1.9), ("height", 1.5), ("radius", 0.6)])),
    ("spirit", OrderedDict([("hp", 900.0), ("damage", 12.0), ("speed", 4.0), ("cooldown", 1.0), ("windup", 0.4),
                            ("reach", 2.3), ("height", 2.3), ("radius", 0.8)])),
])

# The six silhouettes the procedural art has (scripts/art/nether_models.gd), one per old concept. A word
# takes the one its runes lean to most (FORM_OF below); the old six keep their own.
FORMS = ["acceleration", "piercing", "compression", "tension", "reach", "stillness"]
# [MODEL] which silhouette an op leans a word toward, and how hard: (form, weight). A mul op counts its
# distance from 1 in the direction given ("up" / "down"); the rest count as flat weights.
FORM_OF = OrderedDict([
    ("speed", ("acceleration", "up")), ("power", ("piercing", "up")), ("cost", ("compression", "down")),
    ("reflux", ("compression", "down")), ("windup", ("tension", "up")), ("poise", ("tension", "up")),
    ("reach", ("reach", "up")), ("duration", ("stillness", "up")),
])
FLAT_FORM = OrderedDict([("shove", ("acceleration", 0.3)), ("pull", ("tension", 0.3)), ("marks", ("piercing", 0.3)),
                         ("jumps", ("reach", 0.3)), ("pierce", ("piercing", 0.4)), ("through", ("piercing", 0.3)),
                         ("bonus", ("piercing", 0.3)), ("interrupts", ("tension", 0.3)), ("braced", ("compression", 0.3)),
                         ("status", ("stillness", 0.12))])

# The authored words: (id, name, tier, [rune ids in order], meaning). [MODEL] every name and meaning.
# An affinity word uses one affinity's runes, optionally with universal runes (the hybrid rule would
# allow more only for a character holding both, so no authored word mixes two affinities).
WORDS = [
    # --- universal remnants: the six old concepts first (their ids kept), then the rest -------------
    ("acceleration", "Acceleration", "remnant", ["UNI-01a", "UNI-02a"], "it moves, and sooner each time: speed that builds"),
    ("piercing", "Piercing", "remnant", ["UNI-07a", "UNI-09a"], "all of it on one point, driven inside the target"),
    ("compression", "Compression", "remnant", ["UNI-05b", "UNI-25a"], "drawn in small and dense, so less essence holds more"),
    ("tension", "Tension", "remnant", ["UNI-15a", "UNI-12a"], "tethered and drawn back: it builds until it is let go"),
    ("reach", "Reach", "remnant", ["UNI-06b", "UNI-05a"], "out to a distance, and wider when it gets there"),
    ("stillness", "Stillness", "remnant", ["UNI-01b", "UNI-22a"], "held still and steadied: what it touches stays, and the caster stays cool"),
    ("friction", "Friction", "remnant", ["UNI-01a", "UNI-01b"], "motion that meets a hold: it drags at what it touches"),
    ("lurch", "Lurch", "remnant", ["UNI-01b", "UNI-01a"], "it waits, then goes (the same two runes as Friction, the other way round)"),
    ("destruction", "Destruction", "remnant", ["UNI-19b", "UNI-13b"], "unmade, all of it at once"),
    ("reprise", "Reprise", "remnant", ["UNI-13a", "UNI-24a"], "it happens again, and what it did sticks"),
    ("tether", "Tether", "remnant", ["UNI-15a", "UNI-16a"], "joined, then drawn in along the join"),
    ("bulwark", "Bulwark", "remnant", ["UNI-09b", "UNI-19a"], "a shell with a shape to it"),
    ("siphon", "Siphon", "remnant", ["UNI-17b", "UNI-25a"], "takes from the target and comes back clean"),
    ("foresight", "Foresight", "remnant", ["UNI-14b", "UNI-21a"], "the next blow, seen before it comes"),
    # --- universal spirits ---------------------------------------------------------------------------
    ("momentum", "Momentum", "spirit", ["UNI-01a", "UNI-02a", "UNI-11a"], "it gets going, and keeps going"),
    ("cascade", "Cascade", "spirit", ["UNI-04b", "UNI-08b", "UNI-05a"], "one falls, then many, spreading as they go"),
    ("vortex", "Vortex", "spirit", ["UNI-03a", "UNI-16a", "UNI-11a"], "it bends round, draws in, and does not stop"),
    ("severance", "Severance", "spirit", ["UNI-15b", "UNI-07a", "UNI-13b"], "one clean cut with everything behind it"),
    ("vigil", "Vigil", "spirit", ["UNI-01b", "UNI-22a", "UNI-24a"], "held still and steady, and nothing is forgotten"),
    ("rebound", "Rebound", "spirit", ["UNI-16b", "UNI-13a", "UNI-12b"], "thrown back, and back again, let go at once"),
    ("verdict", "Verdict", "spirit", ["UNI-28a", "UNI-03b", "UNI-23a"], "certain, straight and commanded"),
    # --- universal eidolons and asuras ------------------------------------------------------------------
    ("maelstrom", "Maelstrom", "eidolon", ["UNI-03a", "UNI-16a", "UNI-08b", "UNI-11a"], "a turning pull that takes many and keeps on"),
    ("bastion", "Bastion", "eidolon", ["UNI-09b", "UNI-19a", "UNI-15a", "UNI-22a"], "an ordered shell, bound fast and calm inside"),
    ("comet", "Comet", "eidolon", ["UNI-06b", "UNI-03b", "UNI-02a", "UNI-13b"], "from far off, straight and fast, all of it at once"),
    ("unmaking", "Unmaking", "asura", ["UNI-19b", "UNI-15b", "UNI-09a", "UNI-13b", "UNI-26b"], "it comes undone from the inside, once and for good"),
    ("dominion", "Dominion", "asura", ["UNI-23a", "UNI-19a", "UNI-08b", "UNI-15a", "UNI-11a"], "many held to one will, and kept there"),

    # --- water ----------------------------------------------------------------------------------------
    ("undertow", "Undertow", "remnant", ["WAT-2b", "WAT-4b"], "drawn in, then pulled under"),
    ("breaker", "Breaker Wall", "remnant", ["WAT-8a", "WAT-2a"], "a rolling wall that throws what it meets"),
    ("deluge", "Deluge", "remnant", ["WAT-1a", "WAT-3a"], "the ground floods, and every body in it is soaked through"),
    ("tidewrack", "Tidewrack", "spirit", ["WAT-1a", "WAT-8a", "WAT-4a"], "the flood rises, rolls and throws"),
    ("drowning_tide", "Drowning Tide", "eidolon", ["WAT-1a", "WAT-2b", "WAT-4b", "WAT-6b"], "flood, draw in, pull under, and hold it down"),
    # --- fire -----------------------------------------------------------------------------------------
    ("wildfire", "Wildfire", "remnant", ["FIR-1a", "FIR-6a"], "it burns, and leaps to the next body"),
    ("backdraft", "Backdraft", "remnant", ["FIR-3b", "FIR-3a"], "flame rushes in, then blows out"),
    ("banked_coals", "Banked Coals", "remnant", ["FIR-4b", "FIR-1b"], "a low burn kept alive, its heat cashed in"),
    ("firestorm", "Firestorm", "spirit", ["FIR-4a", "FIR-6a", "FIR-3a"], "a fierce fire that leaps and bursts"),
    ("white_heat", "White Heat", "spirit", ["FIR-2a", "FIR-6b", "UNI-07a"], "lit, then driven to one white-hot point"),
    ("conflagration", "Conflagration", "asura", ["FIR-2a", "FIR-4a", "FIR-6a", "FIR-3a", "UNI-11a"], "lit, roaring, leaping, bursting - and it does not go out"),
    # --- earth ----------------------------------------------------------------------------------------
    ("bedrock", "Bedrock", "remnant", ["EAR-3a", "EAR-2a"], "anchored and hardened: it does not move"),
    ("landslide", "Landslide", "remnant", ["EAR-3b", "EAR-5b"], "the ground shakes, then comes down"),
    ("quarry", "Quarry", "remnant", ["EAR-4a", "EAR-6b"], "stone torn up and lifted to throw"),
    ("sinkhole", "Sinkhole", "spirit", ["EAR-3b", "EAR-1b", "EAR-4b"], "shaken, sunk and buried"),
    ("monolith", "Monolith", "spirit", ["EAR-1a", "EAR-2a", "EAR-6a"], "raised, hardened, and too heavy to move"),
    ("living_mountain", "Living Mountain", "eidolon", ["EAR-3a", "EAR-1a", "EAR-2a", "EAR-6a"], "rooted, risen, hard and heavy: a hill that will not be moved"),
    # --- wind -----------------------------------------------------------------------------------------
    ("gale", "Gale", "remnant", ["WIN-1a", "WIN-4a"], "air that pushes, and carries along what it pushes"),
    ("downdraft", "Downdraft", "remnant", ["WIN-3a", "WIN-3b"], "lifted, then slammed down"),
    ("crosswind", "Crosswind", "remnant", ["WIN-4b", "WIN-2a"], "turns the rush aside, and cuts it as it turns"),
    ("cyclone", "Cyclone", "spirit", ["WIN-5a", "WIN-3a", "WIN-5b"], "spun together, lifted, and flung apart"),
    # --- lightning ------------------------------------------------------------------------------------
    ("overcharge", "Overcharge", "remnant", ["LIG-2a", "LIG-2b"], "marks built up, then spent at once"),
    ("forkstrike", "Forkstrike", "remnant", ["LIG-1a", "LIG-3a"], "one bolt that splits to the next target"),
    ("stormclap", "Stormclap", "remnant", ["LIG-5a", "LIG-4b"], "a crack that staggers, and nerves that lock"),
    ("chainstorm", "Chainstorm", "spirit", ["LIG-3a", "LIG-2a", "LIG-4a"], "it jumps, marks and quickens"),
    ("worldstorm", "Worldstorm", "asura", ["LIG-1a", "LIG-2a", "LIG-3a", "LIG-2b", "LIG-5a"], "strike, mark, jump, overload - and the thunder after"),
    # --- ice ------------------------------------------------------------------------------------------
    ("hoarfrost", "Hoarfrost", "remnant", ["ICE-2a", "ICE-4a"], "cold that creeps, then builds ice on what it grips"),
    ("shatterpoint", "Shatterpoint", "remnant", ["ICE-5a", "ICE-4b"], "made fragile, then broken"),
    ("whiteout", "Whiteout", "remnant", ["ICE-3a", "ICE-1a"], "snow that blinds, then locks solid"),
    ("glacier", "Glacier", "spirit", ["ICE-1a", "ICE-6b", "ICE-4a"], "frozen, carried, and built ever thicker"),
    ("permafrost", "Permafrost", "spirit", ["ICE-6a", "ICE-5b", "UNI-11a"], "a halting cold, hardened, that lasts"),
    ("frozen_hour", "Frozen Hour", "eidolon", ["ICE-6a", "ICE-1a", "UNI-01b", "UNI-11a"], "everything stops, locks, stays, and keeps on staying"),
    # --- dark -----------------------------------------------------------------------------------------
    ("nightfall", "Nightfall", "remnant", ["DRK-1a", "DRK-2a"], "darker, until the target is lost in it"),
    ("shadowpin", "Shadowpin", "remnant", ["DRK-3a", "DRK-3b"], "a step through the dark, and the shadow nailed down"),
    ("hollow_maw", "Hollow Maw", "remnant", ["DRK-5a", "DRK-5b"], "swallowed whole, then given back as harm"),
    ("eclipse", "Eclipse", "spirit", ["DRK-1a", "DRK-4a", "DRK-5a"], "dark, silent, and hungry for the light"),
    # --- metal ----------------------------------------------------------------------------------------
    ("keen_edge", "Keen Edge", "remnant", ["MET-1a", "MET-4a"], "shaped hard, then sharpened"),
    ("armourbreak", "Armourbreak", "remnant", ["MET-5b", "MET-3b"], "the plate torn off, then punched through"),
    ("shackle", "Shackle", "remnant", ["MET-2a", "MET-3a"], "welded on, then locked shut"),
    ("anvil_heart", "Anvil Heart", "spirit", ["MET-1a", "MET-5a", "UNI-19a"], "forged and plated in good order"),
    ("siegebreaker", "Siegebreaker", "eidolon", ["MET-2b", "MET-3b", "MET-5b", "UNI-13b"], "split, breached, stripped - all in one blow"),
    # --- blood ----------------------------------------------------------------------------------------
    ("bloodletting", "Bloodletting", "remnant", ["BLD-1a", "BLD-2b"], "wounds opened, and the blood thrown out as a weapon"),
    ("bloodthirst", "Bloodthirst", "remnant", ["BLD-6a", "BLD-2a"], "it reaches for blood, and drinks what it finds"),
    ("scabmail", "Scabmail", "remnant", ["BLD-3a", "BLD-5b"], "blood hardened to a shell, breath held steady"),
    ("exsanguination", "Exsanguination", "spirit", ["BLD-1a", "BLD-2a", "BLD-6b"], "opened, drunk, and drained to the dregs"),
    # --- life -----------------------------------------------------------------------------------------
    ("second_wind", "Second Wind", "remnant", ["LIF-2a", "LIF-1a"], "vigour back, then the wounds closed"),
    ("atrophy", "Atrophy", "remnant", ["LIF-3b", "LIF-1b"], "the body wasted, then withered from within"),
    ("vigour", "Vigour", "remnant", ["LIF-3a", "LIF-2a"], "stronger, and fresh again"),
    ("wellspring", "Wellspring", "spirit", ["LIF-1a", "LIF-5a", "LIF-6b"], "healing that regrows, and gives outward"),
    ("deathless", "Deathless", "asura", ["LIF-1a", "LIF-5a", "LIF-3a", "LIF-2a", "UNI-11a"], "healed, regrown, strong, renewed - and lasting"),
    # --- death ----------------------------------------------------------------------------------------
    ("last_rites", "Last Rites", "remnant", ["DTH-2b", "DTH-1a"], "put down for good: the dying finished"),
    ("gravecall", "Gravecall", "remnant", ["DTH-2a", "DTH-6a"], "the dead get up, and do as they are bid"),
    ("wraithwalk", "Wraithwalk", "remnant", ["DTH-5a", "DTH-5b"], "gone from sight, then there"),
    ("ossuary", "Ossuary", "spirit", ["DTH-3b", "DTH-2a", "DTH-6a"], "the dead kept, raised and sent"),
    ("pale_host", "Pale Host", "eidolon", ["DTH-2a", "DTH-6a", "DTH-4a", "UNI-08b"], "many dead raised, bid, and lingering on"),
    # --- nature ---------------------------------------------------------------------------------------
    ("bramble", "Bramble", "remnant", ["NAT-2a", "NAT-5a"], "growth from the ground that tangles what it reaches"),
    ("reaping", "Reaping", "remnant", ["NAT-4b", "NAT-4a"], "sown to act later, then taken in"),
    ("packrun", "Packrun", "remnant", ["NAT-6a", "NAT-6b"], "beasts gathered, then let off the leash"),
    ("overgrowth", "Overgrowth", "spirit", ["NAT-1a", "NAT-2a", "NAT-3a"], "it grows, sprouts and thrives"),
    # --- light ----------------------------------------------------------------------------------------
    ("burning_glass", "Burning Glass", "remnant", ["LGT-5b", "LGT-6a"], "light bent through a lens into one line"),
    ("dazzle", "Dazzle", "remnant", ["LGT-2a", "LGT-4a"], "a flash, then a glare that blinds"),
    ("spectrum", "Spectrum", "remnant", ["LGT-6b", "LGT-5a"], "split into rays, and turned on"),
    ("dawnbreak", "Dawnbreak", "spirit", ["LGT-1a", "LGT-3a", "LGT-2a"], "light shown, sent outward, and flashing"),
    ("sunlance", "Sunlance", "eidolon", ["LGT-6a", "LGT-5b", "LGT-4b", "UNI-03b"], "one ray, focused, sharp and true"),
    # --- dream ----------------------------------------------------------------------------------------
    ("nightmare", "Nightmare", "remnant", ["DRM-1a", "DRM-3a"], "put to sleep, then given terror"),
    ("glamour", "Glamour", "remnant", ["DRM-2a", "DRM-4a"], "an illusion that wears another's look"),
    ("suggestion", "Suggestion", "remnant", ["DRM-5a", "DRM-6a"], "a command whispered, and the mind won over"),
    ("lullaby", "Lullaby", "spirit", ["DRM-3b", "DRM-1a", "DRM-5a"], "calmed, sent to sleep, and told what to do"),
    # --- poison ---------------------------------------------------------------------------------------
    ("slow_venom", "Slow Venom", "remnant", ["POI-1a", "POI-6a"], "dosed, and left to steep"),
    ("acid_mire", "Acid Mire", "remnant", ["POI-2a", "POI-3a"], "fouled ground that eats armour"),
    ("quickbane", "Quickbane", "remnant", ["POI-1a", "POI-6b"], "dosed, and made to act sooner"),
    ("tainted_ground", "Tainted Ground", "spirit", ["POI-2a", "POI-4a", "POI-5a"], "fouled, lingering, and weakening all who stand in it"),
    # --- disease --------------------------------------------------------------------------------------
    ("contagion", "Contagion", "remnant", ["DIS-1a", "DIS-2a"], "given, then passed body to body"),
    ("gangrene", "Gangrene", "remnant", ["DIS-3a", "DIS-5a"], "wounds rot, and the body's guard falls"),
    ("plague_pit", "Plague Pit", "remnant", ["DIS-6a", "DIS-6b"], "the sick buried, and the grave dug up again"),
    ("pestilence", "Pestilence", "spirit", ["DIS-1a", "DIS-4a", "DIS-2a"], "given, spread as a cloud, and passed on"),
    ("long_fever", "Long Fever", "asura", ["DIS-1a", "DIS-2a", "DIS-3a", "DIS-4a", "DIS-5a"], "given, passed on, festering, billowing, overwhelming"),
    # --- holy -----------------------------------------------------------------------------------------
    ("judgement", "Judgement", "remnant", ["HOL-2b", "HOL-5b"], "marked for judgement, then struck in fury"),
    ("sanctuary", "Sanctuary", "remnant", ["HOL-4a", "HOL-1a"], "a holy place, and a guard over what is yours in it"),
    ("answer", "Answering Zeal", "remnant", ["HOL-6b", "HOL-6a"], "waits for the blow, then drives forward"),
    ("absolution", "Absolution", "spirit", ["HOL-3a", "HOL-5a", "HOL-2a"], "a burden lifted, harm softened, a boon given"),
    ("hallowed_gate", "Hallowed Gate", "eidolon", ["HOL-4a", "HOL-1a", "HOL-4b", "UNI-19a"], "a holy place, guarded, its foes driven out, in good order"),
    # --- unholy ---------------------------------------------------------------------------------------
    ("leechfire", "Leechfire", "remnant", ["UNH-1a", "UNH-1b"], "life drawn out, then poured back as harm"),
    ("cruel_lure", "Cruel Lure", "remnant", ["UNH-2b", "UNH-2a"], "called in, then driven off in fear"),
    ("gloomstalk", "Gloomstalk", "remnant", ["UNH-3a", "UNH-5a"], "darkness that follows, and a hunter in it"),
    ("dirge", "Dirge", "spirit", ["UNH-4b", "UNH-4a", "UNH-1a"], "a life kept failing, torn out, and drunk"),
]

# Old saves and data (Brent: "don't worry about old saves", so this is all there is): the six concepts
# of 2026-09 were carried at every tier. At the remnant tier each IS its new word (same id); at the
# vestige tier it becomes the rune closest to it; at the deeper tiers, a universal word of that tier
# with the same lean. The game resolves an old {tier, concept} through this table (GameData.construct_word).
LEGACY = OrderedDict([
    ("acceleration", OrderedDict([("vestige", "UNI-01a"), ("remnant", "acceleration"), ("spirit", "momentum"), ("eidolon", "comet"), ("asura", "dominion")])),
    ("piercing", OrderedDict([("vestige", "UNI-09a"), ("remnant", "piercing"), ("spirit", "severance"), ("eidolon", "comet"), ("asura", "unmaking")])),
    ("compression", OrderedDict([("vestige", "UNI-05b"), ("remnant", "compression"), ("spirit", "vigil"), ("eidolon", "bastion"), ("asura", "dominion")])),
    ("tension", OrderedDict([("vestige", "UNI-12a"), ("remnant", "tension"), ("spirit", "rebound"), ("eidolon", "bastion"), ("asura", "dominion")])),
    ("reach", OrderedDict([("vestige", "UNI-06b"), ("remnant", "reach"), ("spirit", "cascade"), ("eidolon", "maelstrom"), ("asura", "dominion")])),
    ("stillness", OrderedDict([("vestige", "UNI-01b"), ("remnant", "stillness"), ("spirit", "vigil"), ("eidolon", "bastion"), ("asura", "unmaking")])),
])

NOTE = ("GENERATED by tools/runes/construct_words.py - do not hand-edit; change the tables in the script and re-run "
        "(export_runes_json.py runs it too). Ether constructs. Tier order and the tier-to-stage mapping are canon (design/01 LAW 4, "
        "LAW 5). Brent 2026-11-04 (design/14 section 14): a construct carries a word of runes - a vestige one rune (one vestige for "
        "every rune in runes.json), a remnant two, a spirit three, an eidolon four, an asura five (tier_runes). words: id -> {label, "
        "tier, runes (ordered: order matters, Friction is not Lurch), meaning, affinity ('' = universal), form (the silhouette the "
        "art draws)}. Set over a sealed ring as its keystone, a word applies every op of its runes as a rune at strength = the "
        "tier's keystone weight (runes.json bond_v2 keystone; RingRules.keystone_effect). A word of universal runes fits any "
        "skill; one with an affinity rune fits only a character who may set that rune (Player.can_use_rune). legacy: the six "
        "concepts of 2026-09 by tier -> the word they now are (old saves and data). wild: how each tier behaves when met wild in "
        "the Netherecho (hp, damage per hit to the projection, speed, attack timing, size); nothing spawns an eidolon or an asura "
        "yet, so they have none. Word names and meanings are ours; every number is [MODEL].")


def form_of(ops):
    score = OrderedDict((f, 0.0) for f in FORMS)
    for op in ops:
        kind = op["op"]
        if kind == "mul" and op["group"] in FORM_OF:
            form, way = FORM_OF[op["group"]]
            d = float(op["value"]) - 1.0
            if way == "down":
                d = -d
            if d > 0:
                score[form] += d
        elif kind in FLAT_FORM:
            form, w = FLAT_FORM[kind]
            score[form] += w
    best = max(score.values())
    if best <= 0:
        return "stillness"
    return next(f for f in FORMS if score[f] == best)


def build(runes):
    base = runes["base_runes"]
    uni = runes["universal_runes"]
    every = OrderedDict(list(base.items()) + list(uni.items()))
    words = OrderedDict()
    problems = []
    # every rune is a vestige (Brent 2026-11-04), made, never authored
    for rid, r in every.items():
        words[rid] = OrderedDict([("id", rid), ("label", r["name"]), ("tier", "vestige"), ("runes", [rid]),
                                  ("meaning", r.get("meaning", "")), ("affinity", r.get("affinity", "")),
                                  ("form", form_of(r.get("ops", [])))])
    spelled = {}
    for wid, label, tier, rids, meaning in WORDS:
        if wid in words:
            problems.append("%s: the id is taken" % wid)
            continue
        if tier not in TIER_RUNES or tier == "vestige":
            problems.append("%s: tier '%s' is not an authored tier" % (wid, tier))
            continue
        if len(rids) != TIER_RUNES[tier]:
            problems.append("%s: a %s carries %d runes, not %d" % (wid, tier, TIER_RUNES[tier], len(rids)))
        missing = [x for x in rids if x not in every]
        if missing:
            problems.append("%s: no rune %s" % (wid, missing))
            continue
        if len(set(rids)) != len(rids):
            problems.append("%s: a rune twice" % wid)
        affs = sorted({every[x].get("affinity", "") for x in rids} - {""})
        if len(affs) > 1:
            problems.append("%s: runes of %s - an affinity word uses one affinity (plus universal runes)" % (wid, affs))
        key = tuple(rids)
        if key in spelled:
            problems.append("%s: spelled the same as %s" % (wid, spelled[key]))
        spelled[key] = wid
        if not label or not meaning:
            problems.append("%s: needs a name and a meaning" % wid)
        ops = [op for x in rids for op in every[x].get("ops", [])]
        words[wid] = OrderedDict([("id", wid), ("label", label), ("tier", tier), ("runes", list(rids)), ("meaning", meaning),
                                  ("affinity", affs[0] if affs else ""),
                                  ("form", wid if wid in FORMS else form_of(ops))])
    for old, by_tier in LEGACY.items():
        if list(by_tier.keys()) != TIERS:
            problems.append("legacy %s: needs every tier %s" % (old, TIERS))
        for tier, wid in by_tier.items():
            if wid not in words or words[wid]["tier"] != tier:
                problems.append("legacy %s at %s: '%s' is no %s word" % (old, tier, wid, tier))
            elif words[wid]["affinity"] != "":
                problems.append("legacy %s at %s: '%s' is not universal" % (old, tier, wid))
    # every tier past the first has universal words, and every affinity has remnants
    for tier in TIERS[1:]:
        if not any(w["tier"] == tier and w["affinity"] == "" for w in words.values()):
            problems.append("no universal %s" % tier)
    for aff in runes["affinity_positions"]:
        if not any(w["tier"] == "remnant" and w["affinity"] == aff for w in words.values()):
            problems.append("%s has no remnant" % aff)
    if problems:
        raise SystemExit("construct_words: " + "\n  ".join([""] + problems))
    return OrderedDict([
        ("_note", NOTE),
        ("tiers", TIERS),
        ("tier_runes", TIER_RUNES),
        ("words", words),
        ("legacy", LEGACY),
        ("wild", WILD),
    ])


def write(runes=None):
    if runes is None:
        runes = json.loads(RUNES.read_text(encoding="utf-8"))
    out = build(runes)
    OUT.write_text(json.dumps(out, indent="\t", ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
    counts = OrderedDict((t, 0) for t in TIERS)
    uni = OrderedDict((t, 0) for t in TIERS)
    for w in out["words"].values():
        counts[w["tier"]] += 1
        if w["affinity"] == "":
            uni[w["tier"]] += 1
    print("wrote %s: %s" % (OUT.relative_to(ROOT), ", ".join("%d %s (%d universal)" % (counts[t], t, uni[t]) for t in TIERS)))
    return out


if __name__ == "__main__":
    write()
