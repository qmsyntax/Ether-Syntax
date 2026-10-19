"""Crafting-depth tables for tools/items/build_items_draft.py (design/11-crafting-depth-v0.md).

Data only: skills, tools, the per-band subcombine chain, gear shapes, trivial offsets, the
skill-up / success / salvage rules. Everything here is ours [MODEL]; EverQuest's tradeskills
were read as a reference for how such systems work (design/11 section 2), never copied.
"""
from collections import OrderedDict

SKILL_MAX = 300
POINTS_PER_BAND = 25          # a band's recipes sit between 25 x (band - 1) and 25 x band

# id: (name, kind, stations, tool kind, what it makes)
SKILLS = OrderedDict([
    ("smithing", ("Smithing", "craft", ["forge"], "hammer", "Bars, wire, sheet, rivets, fittings, folded alloy, arrowheads, shot; metal weapons, heavy armour, bucklers, heater shields, flues; most tools")),
    ("leatherwork", ("Leatherwork", "craft", ["leatherworks"], "currier_knife", "Leather from scraped hides, grip wraps, straps; medium armour, staff slings, frames, belts")),
    ("tailoring", ("Tailoring", "craft", ["loom"], "needle_case", "Cloth from fibre, padding, bowstrings, vanes; light armour, slings")),
    ("bowyery", ("Bowyery", "craft", ["bowyer"], "drawknife", "Staves, hafts, arrow shafts; bows, crossbows, round shields; fishing rods")),
    ("fletching", ("Fletching", "craft", ["bowyer"], "jig", "Arrows, bolts and their specials, from shafts, heads and vanes")),
    ("pottery", ("Pottery and Stonework", "craft", ["kiln"], "potters_tools", "Crucibles, vials, moulds, whetstones, sumps; mortars and settling dishes")),
    ("rendering", ("Rendering", "craft", ["flensing_yard"], "flensing_knife", "Scraped hides, tallow, bone meal, marrow, quench oil - what a carcass is worth beyond its hide")),
    ("brewing", ("Brewing and Distilling", "craft", ["still"], "hydrometer", "Spirits (alchemy's solvent, the ether quench's base) and tanning liquor")),
    ("cookery", ("Cookery", "craft", ["hearth", "camp"], "cook_knife", "Field rations and suppers that speed natural healing")),
    ("alchemy", ("Alchemy", "craft", ["alchemist", "camp"], "mortar", "Dressings, salves, regrowth, draughts, pastes, painkillers, tonics, liniment, ascension aids, mender's thread")),
    ("poisoncraft", ("Poisoncraft", "craft", ["alchemist"], "venom_kit", "Weapon coatings: bleeding oil, sap venom, lead lacquer")),
    ("etherwork", ("Etherwork", "craft", ["settling_vat"], "settling_dish", "Ether quench, affinity charges, ether slivers, Netherecho aids (incense, wax, binding salts)")),
    ("setting", ("Setting", "craft", ["runesetter"], "loupe", "Charms, talismans and cooling coils: settled ether set into fittings and wire")),
    ("auragraphy", ("Auragraphy", "craft", ["runesetter"], "stylus", "Rune ink, runes written onto Fine gear, focus tablets [C: auragraphy is writing runes - bible LAW 4c]")),
    ("artifice", ("Artifice", "craft", ["workbench"], "fitters_case", "Trigger locks, windlasses, flue throats, throwables, field kits, loupes and styluses [C: artificers exist - b5 s8]")),
    ("mining", ("Mining", "gather", [], "pick", "Ore, fluxstone, clay, grit-stone from veins and resource caches")),
    ("felling", ("Felling", "gather", [], "saw", "Logs and resin from living trees (harming the living pays the talent [C])")),
    ("foraging", ("Foraging", "gather", [], "sickle", "Flora: knit, bitter and cold herbs, cache fruit, flax")),
    ("fishing", ("Fishing", "gather", [], "rod", "Fish from fen, lake and realm water (venom, oil, food)")),
    ("dowsing", ("Dowsing", "gather", [], "dowsing_rod", "Ether salt and settled ether at ether-rich sites; affinity shards for anyone, very, very rarely")),
])
STATION_SKILL = {"forge": "smithing", "leatherworks": "leatherwork", "loom": "tailoring", "bowyer": "bowyery",
                 "kiln": "pottery", "still": "brewing", "hearth": "cookery", "flensing_yard": "rendering",
                 "workbench": "artifice", "settling_vat": "etherwork", "alchemist": "alchemy", "runesetter": "setting",
                 "camp": "cookery"}
LINE_SKILL = {  # overrides of the station's skill, by line
    "arrows": "fletching", "bolts": "fletching", "barbed_arrows": "fletching", "bodkins": "fletching",
    "blunt_bolts": "fletching", "shot": "smithing",
    "bleeding_oil": "poisoncraft", "sap_venom": "poisoncraft", "lead_lacquer": "poisoncraft",
    "mat_ink": "auragraphy", "tablet_f": "auragraphy", "poultice": "alchemy", "thread": "alchemy",
    "mat_quench": "rendering",
}

# Tool kind: (name, maker station, recipe shape from the band's chain keys, value at band 1, kg)
TOOLS = OrderedDict([
    ("hammer", ("Smith's Hammer", "forge", {"bar": 2, "haft": 1}, 150, 1.5)),
    ("currier_knife", ("Currier's Knife", "forge", {"bar": 1, "grip": 1}, 120, 0.4)),
    ("needle_case", ("Needle Case", "forge", {"wire": 2, "leather": 1}, 100, 0.2)),
    ("drawknife", ("Drawknife", "forge", {"bar": 1, "haft": 1}, 120, 0.8)),
    ("jig", ("Fletcher's Jig", "bowyer", {"stave": 2, "fittings": 1}, 110, 1.2)),
    ("potters_tools", ("Potter's Ribs and Wires", "forge", {"wire": 2, "stave": 1}, 90, 0.6)),
    ("flensing_knife", ("Flensing Knife", "forge", {"bar": 2, "grip": 1}, 130, 0.7)),
    ("hydrometer", ("Hydrometer", "kiln", {"vial": 3, "wire": 1}, 110, 0.2)),
    ("cook_knife", ("Cook's Knife", "forge", {"bar": 1, "grip": 1}, 90, 0.3)),
    ("mortar", ("Mortar and Pestle", "kiln", {"stone": 2}, 100, 1.5)),
    ("venom_kit", ("Venom Kit", "kiln", {"vial": 4, "leather": 1}, 140, 0.5)),
    ("settling_dish", ("Settling Dish", "kiln", {"clay": 2, "salt": 1}, 160, 1.0)),
    ("loupe", ("Setter's Loupe", "workbench", {"vial": 1, "fittings": 1}, 150, 0.1)),
    ("stylus", ("Rune Stylus", "workbench", {"wire": 1, "bone": 1}, 170, 0.1)),
    ("fitters_case", ("Fitter's Case", "forge", {"bar": 1, "wire": 2, "leather": 1}, 160, 1.5)),
    ("pick", ("Miner's Pick", "forge", {"bar": 2, "haft": 1}, 140, 2.5)),
    ("saw", ("Felling Saw", "forge", {"sheet": 1, "haft": 1}, 130, 2.0)),
    ("sickle", ("Gatherer's Sickle", "forge", {"bar": 1, "grip": 1}, 90, 0.5)),
    ("rod", ("Fishing Rod", "bowyer", {"stave": 1, "bowstring": 1}, 80, 1.0)),
    ("dowsing_rod", ("Dowsing Rod", "workbench", {"wire": 2, "salt": 1}, 180, 0.4)),
])
TOOL_TIER_BAND = {1: 1, 2: 4, 3: 7, 4: 10}
TOOL_TIER_PREFIX = {1: "", 2: "Warded ", 3: "Stilled ", 4: "First-Struck "}


def tool_tier(b):
    return 1 if b <= 3 else 2 if b <= 6 else 3 if b <= 9 else 4


# Trivial = 25 x (band - 1) + offset; you may attempt from trivial - ATTEMPT_WINDOW.
TRIVIAL_OFFSET = {"gather": 6, "refine": 8, "sub": 12, "plain": 16, "fine": 22, "runed": 24}
ATTEMPT_WINDOW = 30

# Affinity shards (an affinity's settled stone) by dowsing: open to everyone (Brent 2026-10-18), but VERY, very hard.
# The trivial sits far above the band's; below it a dowse finds a shard at find_chance, at or past it at
# find_chance_at_trivial. Every other dowse at the site still turns up ether salt as usual.
AFFINITY_SHARD = OrderedDict([("extra_trivial", 100), ("find_chance", 0.002), ("find_chance_at_trivial", 0.01)])

CRAFT_RULES = OrderedDict([
    ("_note", "design/11 section 4. Every number is a first guess [MODEL]."),
    ("skill_max", SKILL_MAX),
    ("points_per_band", POINTS_PER_BAND),
    ("skill_cap_by_stars", "none (Brent 2026-10-18): any crafting skill can reach 300 at any star"),
    ("affinity_shards", "anyone may dowse for them; trivial +100 over the band's (to 300), found at 0.2% a dowse below trivial and 1% at or past it [B: open to all, very very hard]"),
    ("trivial", "25 x (band - 1) + offset (gather 6, refine 8, subcombine 12, plain 16, fine 22, runed 24)"),
    ("attempt_from", "trivial - 30 (the recipe is greyed out below that)"),
    ("success", "clamp(0.05, 0.95, 0.70 + (effective skill - trivial) / 50 + 0.03 x (tool tier - tier needed) + station bonus); at or past trivial + 13 a combine cannot fail"),
    ("effective_skill", "skill + 5 per guild mark held in that skill (marks at 50, 100, 150, 200, 250; each needs a witnessed masterwork)"),
    ("failure", "the fee is spent; each input is returned with chance 0.5 (+0.1 per station grade above the recipe's, + the salvage of a field kit's grade 0); tools lose a use either way"),
    ("skill_up", "only below trivial: chance = 0.35 x sqrt((trivial - skill) / 25), capped at 0.60, halved on a failure; first success of any recipe gives +1 for sure; at most +1 per combine"),
    ("tool_wear", "a tool is returned on every combine and loses one use; at 0 uses it breaks"),
    ("crafting_time", "each combine takes the recipe's hours on the world clock (a day is 90 real minutes)"),
    ("growth", "proposed: a combine of your own band or above, below trivial, adds a little latent aura [F: crafting is a source of latent aura - bible LAW 2]; nothing at or past trivial"),
])

# CRAFT_RULES as numbers, for the game (tools/items/emit_crafting_game.py writes them into
# game/data/crafting.json "rules"). Keep the two in step: CRAFT_RULES is the words, this the values.
CRAFT_NUMBERS = OrderedDict([
    ("skill_max", SKILL_MAX),               # no cap by stars (Brent 2026-10-18)
    ("attempt_window", ATTEMPT_WINDOW),     # may try from trivial - this
    ("success_at_trivial", 0.70),
    ("success_per_point", 1.0 / 50.0),      # each point of skill above (or below) trivial
    ("success_floor", 0.05),
    ("success_cap", 0.95),
    ("certain_past_trivial", 13),           # at trivial + this a combine cannot fail
    ("tool_tier_bonus", 0.03),              # success per tool tier above the one needed
    ("station_grade_success", 0.0),         # the "station bonus": none yet
    ("salvage", 0.5),                       # each input back on a failure with this chance
    ("salvage_per_grade", 0.1),             # + this per station grade above the recipe's
    ("skillup_k", 0.35),                    # chance = k x sqrt((trivial - skill) / skillup_scale)
    ("skillup_scale", 25.0),
    ("skillup_cap", 0.60),
    ("skillup_fail_mult", 0.5),             # halved on a failure
    ("first_success_up", 1),                # the first success of each recipe, for sure
    ("tool_uses_per_tier", 150),
])

# The per-band chain of subcombines (design/11 section 5). key: (station, inputs by chain key, makes, fee share,
#   kg, name pattern, description, byproducts). Names use {metal} {leather} {wood} {cloth} {word} {fruit} {hide}.
CHAIN = [
    ("scraped", "flensing_yard", {"hide": 1}, 1, 0.05, 6.0, "Scraped {hide}", "A hide flensed clean and ready for the tanning pit. The fat came off it in buckets.", {"tallow": 2}),
    ("meal", "flensing_yard", {"bone": 1}, 3, 0.05, 0.5, "{word} Bone Meal", "Bone ground to flour. Potters fire it into fine ware; alchemists bind with it.", {"marrow": 1}),
    ("quench", "flensing_yard", {"tallow": 2}, 2, 0.1, 0.5, "{word} Quench Oil", "Rendered fat, strained twice. Hot steel goes into it and comes out hard.", None),
    ("spirit", "still", {"fruit": 2}, 3, 0.1, 0.5, "{fruit} Spirit", "Distilled twice from cache fruit. A solvent first and a drink a distant second.", None),
    ("liquor", "still", {"resin": 1, "bitter": 1}, 2, 0.1, 1.0, "{wood} Tanning Liquor", "Bark resin and bitter herb steeped dark. Hides go in raw and come out leather.", None),
    ("crucible", "kiln", {"clay": 2}, 1, 0.1, 1.5, "{word} Crucible", "A fired clay pot that holds molten metal for one pour. It cracks after.", None),
    ("vial", "kiln", {"clay": 1}, 4, 0.1, 0.1, "{word} Vial", "A small stoppered vial. Every draught and venom needs one.", None),
    ("mould_blade", "kiln", {"clay": 2}, 1, 0.1, 1.0, "{word} Blade Mould", "A two-part clay mould for a blade, knuckle-bar or point. Broken to free the casting.", None),
    ("mould_head", "kiln", {"clay": 2}, 1, 0.1, 1.2, "{word} Head Mould", "A clay mould for an axe-head, mace-head or maul. Broken to free the casting.", None),
    ("mould_plate", "kiln", {"clay": 3}, 1, 0.1, 2.0, "{word} Plate Mould", "A shallow clay form that plate sheet is beaten over. It lasts one piece.", None),
    ("mould_fitting", "kiln", {"clay": 1}, 2, 0.1, 0.5, "{word} Fitting Mould", "A clay block with sockets for buckles, guards, rings and pommels.", None),
    ("whetstone", "kiln", {"stone": 1}, 2, 0.1, 0.5, "{word} Whetstone", "Grit-stone cut and dressed. An edge takes one whetstone's worth of grinding.", None),
    ("bar", "forge", {"ore": 4, "flux": 1, "crucible": 1}, 2, 0.15, 2.0, "{metal} Bar", "A bar of {metal_lc}. {mclause}", None),
    ("wire", "forge", {"bar": 1}, 4, 0.1, 0.3, "{metal} Wire", "Drawn {metal_lc} wire. It holds grips, rims and rings together.", None),
    ("sheet", "forge", {"bar": 1}, 1, 0.1, 2.0, "{metal} Sheet", "{metal} beaten into sheet. Plate, bucklers and flue barrels start here.", None),
    ("rivets", "forge", {"wire": 1}, 4, 0.1, 0.2, "{metal} Rivets", "A bag of {metal_lc} rivets. Armour is mostly rivets with opinions.", None),
    ("fittings", "forge", {"bar": 1, "mould_fitting": 1}, 4, 0.1, 0.3, "{metal} Fittings", "Cast buckles, guards, rings and pommels in {metal_lc}.", None),
    ("alloy", "forge", {"bar": 2, "salt": 1}, 1, 0.2, 2.0, "Folded {metal}", "{metal} folded with ether salt until it holds a better edge. Fine work starts here.", None),
    ("arrowheads", "forge", {"bar": 1, "whetstone": 1}, 3, 0.1, 0.3, "{metal} Arrowheads", "A bag of ground {metal_lc} heads for arrows and bolts.", None),
    ("ether_quench", "settling_vat", {"salt": 1, "spirit": 1}, 2, 0.2, 0.3, "{word} Ether Quench", "Ether salt dissolved in spirit and left to settle. Fine steel is quenched in it.", None),
    ("leather", "leatherworks", {"scraped": 1, "liquor": 1}, 4, 0.05, 2.0, "{leather} Leather", "Tanned and cut into working sides. {lclause}", None),
    ("grip", "leatherworks", {"leather": 1}, 4, 0.1, 0.1, "{leather} Grip Wrap", "Leather cut and skived for wrapping a hilt or a haft.", None),
    ("strap", "leatherworks", {"leather": 1}, 4, 0.1, 0.2, "{leather} Straps", "Straps and laces: what holds armour on a body and a pack on a back.", None),
    ("stave", "bowyer", {"log": 1}, 2, 0.15, 1.5, "{wood} Stave", "Split, seasoned and straight. {wclause}", None),
    ("haft", "bowyer", {"stave": 1}, 2, 0.1, 1.0, "{wood} Haft", "A shaped haft for an axe, a spear or a tool.", None),
    ("shaft", "bowyer", {"stave": 1}, 2, 0.1, 0.5, "{wood} Arrow Shafts", "A bundle of straight shafts, sized for arrows or bolts.", None),
    ("cloth", "loom", {"fibre": 1}, 4, 0.05, 1.0, "{cloth} Bolt", "A bolt of woven cloth. {cclause}", None),
    ("padding", "loom", {"cloth": 1}, 2, 0.1, 0.5, "{cloth} Padding", "Quilted padding. Nothing heavy is worn without it.", None),
    ("bowstring", "loom", {"fibre": 1}, 4, 0.1, 0.05, "{cloth} Bowstring", "A twisted string, waxed. It wants a bow.", None),
    ("vanes", "loom", {"cloth": 1}, 4, 0.1, 0.05, "{cloth} Vanes", "Stiffened cloth vanes for arrows, cut a bundle at a time.", None),
    ("lock", "workbench", {"fittings": 2, "wire": 1}, 1, 0.2, 0.5, "{metal} Trigger Lock", "A crossbow's nut, sear and trigger, fitted to close tolerances.", None),
    ("windlass", "workbench", {"fittings": 2, "haft": 1, "wire": 1}, 1, 0.2, 1.0, "{metal} Windlass", "A crank and cord for spanning heavy bows.", None),
    ("throat", "workbench", {"sheet": 1, "salt": 1}, 1, 0.2, 0.6, "{metal} Flue Throat", "The runed throat of a flue, where reflux is turned into shot.", None),
    ("ink", "runesetter", {"salt": 2, "bitter": 1}, 1, 0.3, 0.2, "{word} Rune Ink", "Enough ink to write one rune onto one thing of this band. The runesetter does not give refunds.", None),
]
# Raw materials and their gathering skill: key: (name pattern, kg, value at band 1, skill, description)
RAWS = OrderedDict([
    ("flux", ("{word} Fluxstone", 1.0, 30, "mining", "Pale stone that burns off the dross when ore is smelted.")),
    ("clay", ("{word} Clay", 2.0, 10, "mining", "Fat clay dug from a bank. Potters wedge it; smiths need what potters make of it.")),
    ("stone", ("{word} Grit-Stone", 2.0, 15, "mining", "A block of hard grit-stone, for whetstones, mortars and tablets.")),
    ("resin", ("{wood} Resin", 0.3, 25, "felling", "Resin tapped from a living tree. Tanners and fletchers both want it.")),
    ("fish", ("{fish}", 1.0, 40, "fishing", "Caught on a line. Its oil, its venom and its meat all have a use.")),
])
FISH = {1: "Sump Eel", 2: "Mire Pike", 3: "Ice Char", 4: "Step Carp", 5: "Vein Loach", 6: "Blind Gar", 7: "Hush Perch",
        8: "Twinned Trout", 9: "Cloud Eel", 10: "First Sturgeon", 11: "Unwritten Fish", 12: "Unmade Fish"}
BYPRODUCTS = {"tallow": ("{word} Tallow", 0.5, 20, "Rendered fat. Quench oil, salves, pastes and candles start as tallow."),
              "marrow": ("{word} Marrow", 0.3, 60, "Marrow from split bone. Regrowth draughts and tonics need it.")}
BAIT = {1: ("Tin of Grubs", 5), 4: ("Warded Lure", 5), 7: ("Stilled Lure", 5), 10: ("First-Struck Lure", 5)}

# Gear shapes with the chain (replaces design/10's): line -> (station, shape; '*' = the primary input).
CRAFT_SHAPES = {
    "knuckles_p": ("forge", {"*bar": 1, "mould_fitting": 1, "quench": 1, "grip": 1}),
    "knuckles_f": ("forge", {"*alloy": 1, "mould_fitting": 1, "ether_quench": 1, "grip": 1, "made": 1}),
    "dagger_p": ("forge", {"*bar": 1, "mould_blade": 1, "quench": 1, "grip": 1}),
    "dagger_f": ("forge", {"*alloy": 1, "mould_blade": 1, "quench": 1, "grip": 1, "made": 1}),
    "blade_p": ("forge", {"*bar": 2, "mould_blade": 1, "quench": 1, "grip": 1, "fittings": 1}),
    "blade_f": ("forge", {"*alloy": 2, "mould_blade": 1, "ether_quench": 1, "grip": 1, "fittings": 1, "made": 1}),
    "axe_p": ("forge", {"*bar": 2, "mould_head": 1, "quench": 1, "haft": 1}),
    "axe_f": ("forge", {"*alloy": 2, "mould_head": 1, "ether_quench": 1, "haft": 1, "made": 1}),
    "hammer_p": ("forge", {"*bar": 2, "mould_head": 1, "quench": 1, "haft": 1}),
    "hammer_f": ("forge", {"*alloy": 3, "mould_head": 1, "ether_quench": 1, "haft": 1, "made": 1}),
    "polearm_p": ("forge", {"*haft": 2, "bar": 1, "mould_blade": 1, "quench": 1}),
    "polearm_f": ("forge", {"*haft": 2, "alloy": 1, "mould_blade": 1, "ether_quench": 1, "made": 1}),
    "great_p": ("forge", {"*bar": 3, "mould_head": 1, "quench": 1, "haft": 1}),
    "great_f": ("forge", {"*alloy": 3, "mould_blade": 1, "ether_quench": 1, "grip": 1, "fittings": 1, "made": 1}),
    "thrown_p": ("forge", {"*bar": 1, "mould_blade": 1, "strap": 1}),
    "thrown_f": ("forge", {"*haft": 2, "arrowheads": 1, "made": 1}),
    "sling_p": ("loom", {"*cloth": 1}),
    "sling_f": ("leatherworks", {"*haft": 1, "strap": 1, "bowstring": 1, "bone": 1}),
    "bow_p": ("bowyer", {"*stave": 2, "bowstring": 1, "resin": 1}),
    "bow_f": ("bowyer", {"*stave": 2, "bowstring": 1, "resin": 1, "grip": 1, "bone": 1}),
    "crossbow_p": ("bowyer", {"*stave": 1, "lock": 1, "bowstring": 1}),
    "crossbow_f": ("bowyer", {"*stave": 2, "lock": 1, "windlass": 1, "bowstring": 1, "bone": 1}),
    "flue_p": ("forge", {"*sheet": 1, "throat": 1}),
    "flue_f": ("forge", {"*sheet": 2, "throat": 1, "ether_quench": 1, "made": 1}),
    "buckler_p": ("forge", {"*sheet": 1, "fittings": 1, "strap": 1}),
    "shield_p": ("bowyer", {"*stave": 2, "fittings": 1, "strap": 1}),
    "shield_f": ("forge", {"*sheet": 2, "fittings": 1, "strap": 1, "padding": 1, "made": 1}),
    "sump_p": ("kiln", {"*clay": 2, "salt": 1}),
    "tablet_f": ("runesetter", {"*stone": 2, "ink": 1, "made": 1}),
    "light_head_p": ("loom", {"*cloth": 1}),
    "light_body_p": ("loom", {"*cloth": 2, "padding": 1}),
    "light_hands_p": ("loom", {"*cloth": 1}),
    "light_feet_p": ("loom", {"*cloth": 1, "strap": 1}),
    "light_body_f": ("loom", {"*cloth": 3, "padding": 1, "fittings": 1, "bone": 1}),
    "med_head_p": ("leatherworks", {"*leather": 1, "rivets": 1}),
    "med_body_p": ("leatherworks", {"*leather": 3, "rivets": 1, "strap": 1}),
    "med_hands_p": ("leatherworks", {"*leather": 1, "strap": 1}),
    "med_feet_p": ("leatherworks", {"*leather": 1, "rivets": 1}),
    "med_body_f": ("leatherworks", {"*leather": 3, "sheet": 1, "rivets": 1, "padding": 1, "bone": 1}),
    "heavy_head_p": ("forge", {"*sheet": 2, "rivets": 1, "padding": 1, "mould_plate": 1}),
    "heavy_body_p": ("forge", {"*sheet": 5, "rivets": 1, "padding": 1, "strap": 1, "mould_plate": 1}),
    "heavy_hands_p": ("forge", {"*sheet": 2, "rivets": 1, "padding": 1}),
    "heavy_feet_p": ("forge", {"*sheet": 2, "rivets": 1, "padding": 1}),
    "heavy_body_f": ("forge", {"*alloy": 4, "rivets": 1, "padding": 1, "strap": 2, "mould_plate": 1, "made": 1}),
    "frame_p": ("leatherworks", {"*haft": 2, "strap": 2, "leather": 1}),
    "belt_p": ("leatherworks", {"*strap": 2, "fittings": 1}),
}
# Fine recipes are learned from a guild's pattern book (design/11 section 4.6), one per skill and band.
PATTERN_SKILLS = ["smithing", "leatherwork", "tailoring", "bowyery", "auragraphy", "setting", "alchemy"]
REGION_WORD = {1: "Tithebarrow", 2: "Winchgate", 3: "Cairnfast"}
