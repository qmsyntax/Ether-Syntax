"""Tables for tools/skills/emit_abilities.py: the parts of the game data that are not in the skill drafts.

- AFF_ORDER and AFFINITIES: each affinity's colour, label, description and its rule as data keys (read
  generically by the game: Player.deal_damage / apply_hit, enemy.gd, the HUD). The rule as text comes from the
  draft. Colours were picked to stay apart from each other on the dark UI (check_colours() below).
- STATUSES: every status as data with generic keys, read in one place in enemy.gd (Enemy._st_* helpers). The
  first thirteen are the statuses the game already had, unchanged; the rest come from the drafts' new_mechanics.
  Duplicates across drafts are merged into one each (MERGED below says which).
- KIND_MAP: draft kinds -> game kinds. hex / smite / seize / gaze are one kind, 'smite'.
- RENAMES: duplicate skill ids across drafts.
- GAP_FILLS: the twelve "good modifier with nothing to act on" data gaps of design/runes-data/modifier-check-planned.md.
- MAGNITUDE: the main magnitude of each self buff and channel, which a rune's power op scales.

All numbers are the drafts' [MODEL] numbers unless marked.
"""
from collections import OrderedDict as OD

import re

AFF_ORDER = ["water", "fire", "earth", "wind", "lightning", "ice", "dark", "metal", "blood", "life", "death",
             "nature", "light", "dream", "poison", "disease", "holy", "unholy"]

# a workbook base rune id (design/runes-workbook.xlsx "Base Runes"): three letters, the pair, a or b
RUNE_ID = re.compile(r"[A-Z]{3}-\d+[ab]")
# a draft's starter_slot, in kit order
STARTER_SLOTS = ["ranged", "close", "movement"]

# Existing affinities keep every key they had. New ones: label, colour, desc (from the draft rule) and the
# rule's data keys. Keys are documented in game/data/affinities.json's _note (written by the emitter).
AFFINITIES = OD([
    ("water", OD([("label", "Water"), ("color", "2f7fd6"),
                  ("desc", "The bruiser. You decide where everyone stands: every skill shoves or drags, what is shoved into something is Crushed, and every Crush shores you up with Ward."),
                  ("marks_adrift", True),
                  # v2 (water.json crush_ward): each Crush you cause adds per_crush Ward, at most cap from this source, each lasting `lasts`
                  ("crush_ward", OD([("per_crush", 15.0), ("cap", 60.0), ("lasts", 6.0)]))])),
    ("fire", OD([("label", "Fire"), ("color", "e2632a"),
                 ("desc", "You get hotter, and so does everything near you. Your own heat is your damage - right up to the moment it locks."),
                 ("damage_per_reflux", 0.6), ("reflux_shed_mult_combat", 0.5)])),
    ("earth", OD([("label", "Earth"), ("color", "a8824a"),
                  ("desc", "The area tank. Slow, heavy and sure: you raise stone, stand Braced, break poise and call the enemy onto you."),
                  ("stone", True), ("reflux_shed_mult", 0.5)])),
    ("wind", OD([("label", "Wind"), ("color", "9fd6c4"),
                 ("desc", "The evasive monk. You are only dangerous while you are moving: run and the pips fill, stand to think and they drain; turn blows aside and strike the back."),
                 ("slipstream", True), ("reflux_shed_mult_moving", 3.0), ("reflux_shed_mult_standing", 0.0), ("rear_bonus", 0.5)])),
    ("lightning", OD([("label", "Lightning"), ("color", "c9b5ff"),
                      ("desc", "The spellblade (Fire's burst, Wind's speed). One target, three touches, gone; every Overload leaves you Quickened. Its heat does not bleed off in a fight."),
                      ("reflux_shed_mult_combat", 0.0),
                      # v2 (lightning.json quicken_on_overload): each Overload you cause leaves you Quickened this long
                      ("quicken_on_overload", 1.5)])),
    # --- new (2026-10-22 drafts) ---
    ("ice", OD([("label", "Ice"), ("color", "7fd8ff"),
                ("desc", "Control (Water's flow, Dark's stillness). Cold stays: lay Chill until they lock solid, then break them with one hard hit. Wet things freeze faster."),
                # v2 (ice.json wet_freezes): an ice hit that lays Chill on a Soaked target (Waterlogged counts) adds this
                # many more, and the Soak ends - the water is now ice
                ("bonus_stacks_vs", OD([("status", "chilled"), ("vs", OD([("soaked", 1)])), ("ends_vs", True)]))])),
    ("dark", OD([("label", "Dark"), ("color", "9a6bd1"),
                 ("desc", "Strongest where the light is weakest. Make your own dark, stand in it unseen, and hit them while they stand in it."),
                 ("light_mult", OD([("dark", 1.25), ("lit", 0.8)])), ("unseen_in_dark", True),
                 # v2 (dark.json ambush): your first hit while Unseen counts as from behind and does this much
                 ("ambush_mult", 1.5)])),
    ("metal", OD([("label", "Metal"), ("color", "b8c2cc"),
                  ("desc", "The armoured duellist (Earth's ground, Fire's forge). Armour is your target; every metal blow on the same enemy heats your edge."),
                  ("per_metal_class", 0.25), ("through", True),
                  # v2 (metal.json Edge Heat): a metal hit on the same enemy as your last adds one, up to focus_max, each +focus_mult;
                  # another enemy starts again at 1; focus_cools_s without a metal hit drops it to 0
                  ("focus_max", 5), ("focus_mult", 0.08), ("focus_cools_s", 3.0)])),
    ("blood", OD([("label", "Blood"), ("color", "d23a48"),
                  ("desc", "The berserker (Life and Death spilled). Open Bleeding, drink the pools, hold the blood: every measure you hold makes your blows harder. Never your own health."),
                  ("held_blood", True),
                  # v2 (blood.json Bloodrush): every hit you deal is x (1 + this x held blood)
                  ("damage_per_held_blood", 0.02)])),
    ("life", OD([("label", "Life"), ("color", "f29ab8"),
                 ("desc", "The healer. Inside living bodies: past armour and shields, hardest on the hale, nothing to the unliving. It mends you and your living summons, faster just after you land a hit."),
                 ("through", True), ("living_only", True), ("hale_mult", 1.25),
                 # v2 (life.json heal_mult_after_hit): Life heals over time run this much faster for after_hit_s after you land a hit;
                 # a self buff with a radius is shared with your living summons only
                 ("heal_mult_after_hit", 1.5), ("after_hit_s", 2.0), ("shares_living_only", True)])),
    ("death", OD([("label", "Death"), ("color", "ddd3b4"),
                  ("desc", "The necromancer. What has died stays useful: corpses lie longer for you, up to three of your dead fight for you, and the Dying take more."),
                  ("dying_mult", 1.3), ("corpse_lie_s", 20.0),
                  # v2 (death.json rule_keys): at most this many thralls stand for you at once
                  ("thrall_cap", 3)])),
    ("nature", OD([("label", "Nature"), ("color", "4fae5a"),
                   ("desc", "The druid (Earth's ground, Life's growth). Plant growth that stays, spreads and ages; stand in it to regrow, call beasts up out of it, then cash it in.")])),
    ("light", OD([("label", "Light"), ("color", "ffd866"),
                  ("desc", "The ranged caster. Light arrives at once along a straight line; whatever it touches is Lit, and a light hit on a Lit target Sears it."),
                  # v2 (light.json sear): a light hit on a target already Lit does this much more and refreshes Lit
                  ("sear_vs_lit", 0.25)])),
    ("dream", OD([("label", "Dream"), ("color", "e58ae0"),
                  ("desc", "Takes hold only of a mind that can see you, or one asleep. Past armour and shields, harder on the Dazed and the Asleep."),
                  ("needs_seen", True), ("through", True),
                  ("bonus_vs_status", OD([("dazed", 0.3), ("asleep", 0.3)])),
                  ("status_time_vs", OD([("dazed", 1.5), ("asleep", 1.5)])),
                  # v2 (dream.json twilight): its statuses last this much longer on a target standing in Dim light
                  ("status_time_dim", 1.25)])),
    ("poison", OD([("label", "Poison"), ("color", "a8e04a"),
                   ("desc", "Coating (Water's taint, Death deferred). A coat puts its payload on every weapon hit and shot; the first dose starts a 6 s clock, the rest add to the bill, and the clock pays it all at once.")])),
    ("disease", OD([("label", "Disease"), ("color", "9fa848"),
                    ("desc", "Plague (Earth's rot, Death's feeding). It lives in flesh and clouds: a carrier passes it to anyone who stays beside it. Armour cuts it, shields and facing do not."),
                    ("times_flesh", True), ("through", True)])),
    # --- new (2026-10-24 v2 drafts) ---
    ("holy", OD([("label", "Holy"), ("color", "f7e7a0"),
                 ("desc", "The paladin (Light and Life). Wards take blows before your bar, and a ward that breaks pays out its light; it covers you and your summons, and its healing touches only the living."),
                 # holy.json rule_data: when the ward pool is emptied by a blow, this goes off round the bearer
                 ("ward_break_payload", OD([("radius", 3.0), ("damage", 30.0), ("status", "lit")])),
                 ("shares_living_only", True)])),
    ("unholy", OD([("label", "Unholy"), ("color", "a85c8c"),
                   ("desc", "The shadow knight (Dark and Death). Every hit drains part of the harm back to you as health, twice that from the Dying or from anything in the Dark, and banks it as stolen life for your skills."),
                   # unholy.json rule_keys: the drain rule and the stolen store
                   ("drain_frac", 0.1), ("drain_mult_vs", OD([("dying", 2.0), ("in_dark", 2.0)])), ("drain_max_frac", 0.5),
                   ("drain_living_only", True), ("drain_heals", "bar"), ("stolen", OD([("max", 100), ("fade_s", 12.0)]))])),
])

# The affinity framework (design/affinities/framework.md, Brent 2026-10-24 [B]): eight bases, and every other
# affinity a hybrid of two bases. Each affinity in the game gets "kind" ("base" | "hybrid"), "parents" (a hybrid's
# two bases, [] for a base) and "role" (the framework's one line). Holy and Unholy are listed but have no draft, so
# the emitter leaves them out of affinities.json until they exist; nothing offers an affinity the game lacks.
LINEAGE = OD([
    ("water", ("base", [], "Bruiser - heavy hits, shoves, crushes")),
    ("fire", ("base", [], "Burst caster - big hits, spreading burns")),
    ("earth", ("base", [], "Area tank - walls, terrain, immovable")),
    ("wind", ("base", [], "Evasive monk - positioning, rear hits, speed")),
    ("light", ("base", [], "Ranged caster - reveal, smite")),
    ("dark", ("base", [], "Assassin - stealth, rear hits, darkness")),
    ("life", ("base", [], "Healer - regrowth, the living only")),
    ("death", ("base", [], "Necromancer - corpses, thralls, the dying")),
    ("lightning", ("hybrid", ["fire", "wind"], "Spellblade - burst and speed")),
    ("metal", ("hybrid", ["earth", "fire"], "Armoured duellist - ground and forge")),
    ("nature", ("hybrid", ["earth", "life"], "Druid - growth, buffs")),
    ("ice", ("hybrid", ["water", "dark"], "Control - flow made still")),
    ("blood", ("hybrid", ["life", "death"], "Berserker - spilled life, never your own")),
    ("holy", ("hybrid", ["light", "life"], "Paladin - support")),
    ("unholy", ("hybrid", ["dark", "death"], "Shadow knight")),
    ("dream", ("hybrid", ["light", "dark"], "Enchanter - twilight")),
    ("poison", ("hybrid", ["water", "death"], "Coating - tainted water that pays out later")),
    ("disease", ("hybrid", ["earth", "death"], "Plague - rot")),
])


def check_lineage():
    """Problems with LINEAGE: a hybrid without exactly two base parents, a base with parents."""
    out = []
    for aff, (kind, parents, _role) in LINEAGE.items():
        if kind == "base" and parents:
            out.append("%s is a base with parents" % aff)
        if kind == "hybrid" and (len(parents) != 2 or any(LINEAGE.get(p, ("",))[0] != "base" for p in parents)):
            out.append("%s needs two base parents, has %s" % (aff, parents))
        if kind not in ("base", "hybrid"):
            out.append("%s has kind %s" % (aff, kind))
    return out


# reflux tier -> reflux_per_cost when a draft gives none (design/05 cost tiers: low 0.4-0.7, middling 1.0, high 1.4)
REFLUX_TIER = {"low": 0.7, "middling": 1.0, "high": 1.4}

# Rule numbers that belong to one affinity but are read by the shared systems (game/data/affinities.json).
AFFINITY_RULE_NUMBERS = OD([
    ("blood", OD([("held_blood_max", 10), ("held_blood_thin_s", 5.0), ("held_blood_per_bleeding_kill", 2),
                  ("pool", OD([("radius", 0.5), ("life", 15.0), ("max", 12), ("death_radius", 1.0), ("death_measures", 3)]))])),
    ("nature", OD([("growth", OD([("radius", 1.0), ("ages", [5.0, 15.0]), ("age_mult", [1.0, 1.5, 2.0]), ("spread_every", 5.0),
                                  ("max", 12), ("bramble", OD([("tick_s", 1.0), ("payload", OD([("damage", 6.0), ("status", "slowed")]))])),
                                  ("snarevine", OD([("tick_s", 4.0), ("payload", OD([("status", "rooted")]))]))])),
                   # v2 (nature.json in_the_green): you and your summons on your own growth regrow, and are hard to move
                   ("in_the_green", OD([("heal_per_s", 1.5), ("shove_mult", 0.5), ("poise_loss_mult", 0.5)]))])),
    ("dark", OD([("unseen_beyond", 4.0), ("reveal_s", 1.0)])),
])

# --- statuses -----------------------------------------------------------------------------------
# Generic keys (read by enemy.gd in one place; see the _note the emitter writes into statuses.json):
#   label, color, stacks (max), lasts (s), no_refresh (a new stack does not reset the clock),
#   move_mult (also the old speed_mult), move_mult_per_stack, attack_speed_mult (also attack_rate_mult),
#   windup_mult, cannot_act, cannot_attack, cannot_move, no_call (no drum, no reinforcements),
#   dps_per_stack, dps_per_metal_class, tick_s, dot_tags, moving_mult, times_flesh, living_only,
#   damage_taken_mult, damage_taken_except (tags), damage_taken_from {affinity: mult}, armour_mult,
#   armour_mult_per_stack, front_block_off, counts_rear, deals_mult, no_poise_damage, poise_regen_off,
#   poise_max_mult, poise_per_s, nudge_per_s, spreads {radius, time}, jumps_on_death, on_expire,
#   on_cap {status, clear, elite_status}, on_death, wakes_on_hit, then_status, needs_first, blocked_by,
#   ends, blocks, counts_as, flees, blinded {sight, melee_reach}, lighter_class, reach_mult,
#   floor_health, kneels_below, no_heal, freezes [ids], control (a hold: once per target per cast from a
#   ticking payload), heavy_lasts_mult, elite_status, derived ("below_half" | "above_half"),
#   alias_of, shatter {hard_poise, damage, radius, shard, ends}, light_radius, retch_every, retch_s,
#   ends_after_damage, makes_interruptible, staggers_in_windup, lure_radius, cap_raise {id: n},
#   dps_mult {id: m}, immovable, shove_mult (Soaked; also Stilled's next shove), ends_on_shove.
EXISTING_STATUSES = OD([
    ("soaked", OD([("label", "Soaked"), ("stacks", 1), ("lasts", 6.0), ("color", "4f9be8"), ("shove_mult", 1.5),
                   ("conduct_radius", 4.0), ("conduct_marks", 1)])),
    ("live", OD([("label", "Live"), ("stacks", 3), ("lasts", 8.0), ("color", "d9c8ff"), ("overload_damage", 150.0), ("stun", 1.0),
                 ("arc_damage", 60.0), ("arc_radius", 12.0), ("grounds", 12.0)])),
    ("stunned", OD([("label", "Stunned"), ("stacks", 1), ("lasts", 1.0), ("color", "fff2a8"), ("cannot_act", True), ("control", True)])),
    ("staggered", OD([("label", "Staggered"), ("stacks", 1), ("lasts", 1.5), ("color", "ffd27a"), ("damage_taken_mult", 1.3),
                      ("cannot_act", True)])),
    ("alight", OD([("label", "Alight"), ("stacks", 5), ("lasts", 5.0), ("color", "ff8a3c"), ("dps_per_stack", 8.0), ("tick_s", 0.5),
                   ("spread_radius", 1.2), ("spread_time", 1.0), ("dot_tags", ["dot", "fire", "alight"]), ("jumps_on_death", True),
                   ("ends", ["chilled"]), ("light_radius", 2.0)])),
    ("aloft", OD([("label", "Aloft"), ("stacks", 1), ("lasts", 1.2), ("color", "bfe9dc"), ("damage_taken_mult", 1.25),
                  ("heavy_poise", 50.0), ("cannot_act", True), ("control", True)])),
    ("frenzied", OD([("label", "Frenzied"), ("stacks", 1), ("lasts", 6.0), ("color", "ff5a4a"), ("speed_mult", 1.3), ("attack_rate_mult", 1.3)])),
    ("drummed", OD([("label", "Drummed"), ("stacks", 1), ("lasts", 1.0), ("color", "d9694f"), ("attack_rate_mult", 1.25), ("poise_mult", 1.5)])),
    ("roused", OD([("label", "Roused"), ("stacks", 1), ("lasts", 12.0), ("color", "ffffff")])),
    ("dazed", OD([("label", "Dazed"), ("stacks", 1), ("lasts", 3.0), ("color", "fff2a8"), ("damage_taken_mult", 1.5)])),
    # Brent 2026-10-23 (Bond Rules rows 69-70): an interrupt carried at a strength above the silence line
    # also silences - it cannot start an attack or call for help. How long comes from the hit (the rune
    # word's strength); "lasts" is only the fallback. [MODEL: cannot cast = cannot_attack + no_call]
    ("silenced", OD([("label", "Silenced"), ("stacks", 1), ("lasts", 1.5), ("color", "9fc3e8"), ("cannot_attack", True),
                     ("no_call", True), ("control", True)])),
    ("pinned", OD([("label", "Pinned"), ("stacks", 1), ("lasts", 2.0), ("color", "bfe9dc"), ("speed_mult", 0.4), ("control", True),
                   ("heavy_lasts_mult", 1.0)])),
    ("slowed", OD([("label", "Slowed"), ("stacks", 1), ("lasts", 3.0), ("color", "a8824a"), ("speed_mult", 0.6)])),
    ("mired", OD([("label", "Mired"), ("stacks", 1), ("lasts", 0.7), ("color", "4f9be8"), ("speed_mult", 0.7)])),
])

NEW_STATUSES = OD([
    # ice: Chill -> Frozen -> Brittle, and the Shatter
    ("chilled", OD([("label", "Chilled"), ("stacks", 5), ("lasts", 10.0), ("color", "8fe6f2"), ("move_mult_per_stack", 0.92),
                    ("on_cap", OD([("status", "frozen"), ("clear", True), ("elite_status", "brittle")]))])),
    ("frozen", OD([("label", "Frozen"), ("stacks", 1), ("lasts", 3.0), ("color", "dff7ff"), ("cannot_act", True), ("control", True),
                   ("heavy_lasts_mult", 0.5), ("damage_taken_mult", 0.5), ("damage_taken_except", ["shatter"]),
                   ("counts_as", ["brittle"]), ("on_expire", OD([("status", "chilled"), ("stacks", 2)]))])),
    ("brittle", OD([("label", "Brittle"), ("stacks", 1), ("lasts", 5.0), ("color", "c9f2ff"),
                    ("shatter", OD([("hard_poise", 40.0), ("damage", 100.0), ("radius", 2.5),
                                    ("shard", OD([("damage", 40.0), ("status", "chilled")])), ("ends", ["frozen", "brittle"])]))])),
    # sight: one Blinded for fire, light, dark and ice (merged)
    ("blinded", OD([("label", "Blinded"), ("stacks", 1), ("lasts", 3.0), ("color", "f6f0d0"),
                    ("blinded", OD([("sight", 2.0), ("melee_reach", 1.5)]))])),
    ("lit", OD([("label", "Lit"), ("stacks", 1), ("lasts", 6.0), ("color", "ffe9a0"), ("armour_mult", 0.5), ("light_radius", 1.5),
                ("ends", ["masked"])])),
    ("exposed", OD([("label", "Exposed"), ("stacks", 1), ("lasts", 6.0), ("color", "c8b4ff"), ("counts_rear", True), ("front_block_off", True)])),
    ("shadowbound", OD([("label", "Shadowbound"), ("stacks", 1), ("lasts", 2.5), ("color", "6c5aa0"), ("cannot_move", True),
                        ("immovable", True), ("control", True)])),
    # metal
    ("rusting", OD([("label", "Rusting"), ("stacks", 1), ("lasts", 5.0), ("color", "b8643a"), ("dps_per_metal_class", 6.0),
                    ("tick_s", 1.0), ("dot_tags", ["dot", "metal", "rusting"]), ("armour_mult", 0.5)])),
    ("fused", OD([("label", "Fused"), ("stacks", 1), ("lasts", 5.0), ("color", "d8d0c0"), ("move_mult", 0.6)])),
    ("shackled", OD([("label", "Shackled"), ("stacks", 1), ("lasts", 2.5), ("color", "a0a8b0"), ("cannot_attack", True), ("control", True)])),
    ("stripped", OD([("label", "Stripped"), ("stacks", 1), ("lasts", 8.0), ("color", "e0e4e8"), ("front_block_off", True),
                     ("damage_taken_mult", 1.2), ("metal_class_off", True)])),
    ("dulled", OD([("label", "Dulled"), ("stacks", 1), ("lasts", 6.0), ("color", "8a9098"), ("deals_mult", 0.65), ("no_poise_damage", True)])),
    # blood
    ("bleeding", OD([("label", "Bleeding"), ("stacks", 5), ("lasts", 6.0), ("color", "d23a48"), ("dps_per_stack", 4.0), ("tick_s", 0.5),
                     ("moving_mult", 2.0), ("dot_tags", ["dot", "blood", "bleeding"]), ("drips_pool_s", 1.5),
                     ("on_death", OD([("pool", True), ("held_blood", 2)]))])),
    ("sluggish", OD([("label", "Sluggish"), ("stacks", 1), ("lasts", 1.0), ("color", "8a3040"), ("move_mult", 0.7), ("windup_mult", 1.5),
                     ("dps_mult", OD([("bleeding", 0.5)]))])),
    ("choked", OD([("label", "Choked"), ("stacks", 1), ("lasts", 2.5), ("color", "a02838"), ("cannot_attack", True), ("no_call", True),
                   ("move_mult", 0.5), ("control", True)])),
    # life
    ("withering", OD([("label", "Withering"), ("stacks", 3), ("lasts", 6.0), ("color", "c87a9a"), ("dps_per_stack", 7.0), ("tick_s", 0.5),
                      ("dot_tags", ["dot", "life", "withering", "through"]), ("living_only", True)])),
    ("spent", OD([("label", "Spent"), ("stacks", 1), ("lasts", 4.0), ("color", "d0a0b8"), ("move_mult", 0.75), ("attack_speed_mult", 0.7),
                  ("living_only", True)])),
    ("wasted", OD([("label", "Wasted"), ("stacks", 1), ("lasts", 6.0), ("color", "b88aa0"), ("deals_mult", 0.7), ("poise_max_mult", 0.6),
                   ("living_only", True)])),
    ("sick", OD([("label", "Sick"), ("stacks", 1), ("lasts", 8.0), ("color", "a8b060"), ("retch_every", 2.5), ("retch_s", 0.5),
                 ("living_only", True)])),
    ("arrested", OD([("label", "Arrested"), ("stacks", 1), ("lasts", 8.0), ("color", "e0b0c8"), ("no_heal", True), ("poise_regen_off", True),
                     ("freezes", ["withering", "spent", "wasted", "sick"]), ("living_only", True)])),
    ("hale", OD([("label", "Hale"), ("stacks", 1), ("lasts", 0.0), ("color", "f29ab8"), ("derived", "above_half")])),
    # death
    ("dying", OD([("label", "Dying"), ("stacks", 1), ("lasts", 0.0), ("color", "ddd3b4"), ("derived", "below_half")])),
    ("spared", OD([("label", "Spared"), ("stacks", 1), ("lasts", 4.0), ("color", "fff4d8"), ("floor_health", 1.0), ("kneels_below", 0.5)])),
    ("rotting", OD([("label", "Rotting"), ("stacks", 1), ("lasts", 6.0), ("color", "8a8a50"), ("armour_mult", 0.5), ("poise_regen_off", True)])),
    ("dread", OD([("label", "Dread"), ("stacks", 1), ("lasts", 1.5), ("color", "7a7090"), ("flees", "zone"), ("cannot_attack", True)])),
    # nature
    ("dwindled", OD([("label", "Dwindled"), ("stacks", 1), ("lasts", 8.0), ("color", "7ab070"), ("lighter_class", True), ("reach_mult", 0.7)])),
    ("blighted", OD([("label", "Blighted"), ("stacks", 1), ("lasts", 8.0), ("color", "806a3a"), ("armour_mult", 0.5), ("windup_mult", 1.5),
                     ("damage_taken_from", OD([("nature", 1.2)]))])),
    # rooted is merged into pinned (one hold)
    ("rooted", OD([("alias_of", "pinned")])),
    # dream
    ("asleep", OD([("label", "Asleep"), ("stacks", 1), ("lasts", 4.0), ("color", "c0a8ff"), ("cannot_act", True), ("control", True),
                   ("wakes_on_hit", True), ("then_status", "wakeful"), ("needs_first", "dazed"), ("blocked_by", ["wakeful"]),
                   ("heavy_lasts_mult", 0.5), ("elite_status", "dazed")])),
    ("wakeful", OD([("label", "Wakeful"), ("stacks", 1), ("lasts", 6.0), ("color", "fff0c0")])),
    ("terrified", OD([("label", "Terrified"), ("stacks", 1), ("lasts", 2.0), ("color", "a070c0"), ("flees", "source"), ("cannot_attack", True),
                      ("control", True), ("heavy_lasts_mult", 0.5), ("elite_status", "dazed")])),
    ("soothed", OD([("label", "Soothed"), ("stacks", 1), ("lasts", 1.0), ("color", "c8d8ff"), ("move_mult", 0.7), ("cannot_attack", True),
                    ("wakes_on_hit", True), ("heavy_lasts_mult", 0.5), ("elite_status", "dazed")])),
    ("masked", OD([("label", "Masked"), ("stacks", 1), ("lasts", 4.0), ("color", "e58ae0"), ("lure_radius", 8.0),
                   ("heavy_lasts_mult", 0.5), ("elite_status", "dazed")])),
    ("read", OD([("label", "Read"), ("stacks", 1), ("lasts", 8.0), ("color", "fff8e0"), ("makes_interruptible", True),
                 ("staggers_in_windup", True), ("ends", ["masked"])])),
    ("commanded", OD([("label", "Commanded"), ("stacks", 1), ("lasts", 4.0), ("color", "d8a8f0"), ("cannot_attack", True),
                      ("wakes_on_hit", True), ("goes_to_goal", True), ("heavy_lasts_mult", 0.5), ("elite_status", "dazed")])),
    ("shut", OD([("label", "Shut"), ("stacks", 1), ("lasts", 8.0), ("color", "9080a8"), ("ends", ["drummed", "roused"]),
                 ("blocks", ["drummed", "roused"]), ("no_call", True)])),
    # poison
    ("dosed", OD([("label", "Dosed"), ("stacks", 10), ("lasts", 6.0), ("color", "a8e04a"), ("no_refresh", True),
                  ("on_expire", OD([("damage_per_stack", 20.0), ("tags", ["dot", "poison", "dosed"])]))])),
    ("corroded", OD([("label", "Corroded"), ("stacks", 3), ("lasts", 10.0), ("color", "c0d040"), ("armour_mult_per_stack", 0.667),
                     ("flesh_per_stack", 0.15)])),
    ("sapped", OD([("label", "Sapped"), ("stacks", 1), ("lasts", 2.0), ("color", "90b040"), ("deals_mult", 0.7), ("move_mult", 0.7)])),
    # disease
    ("infected", OD([("label", "Infected"), ("stacks", 5), ("lasts", 6.0), ("color", "b9a85c"), ("dps_per_stack", 6.0), ("tick_s", 0.5),
                     ("times_flesh", True), ("dot_tags", ["dot", "disease", "infected"]),
                     # v2 (disease.json): an enemy that stays within 1.5 m of a carrier for 1 s catches one stack
                     ("spread_radius", 1.5), ("spread_time", 1.0),
                     ("on_death", OD([("cloud", OD([("radius", 1.0), ("life", 4.0), ("tick_s", 1.0),
                                                     ("payload", OD([("status", "infected")]))]))]))])),
    ("contained", OD([("label", "Contained"), ("stacks", 1), ("lasts", 10.0), ("color", "8a7a40"), ("cap_raise", OD([("infected", 10)])),
                      ("dps_mult", OD([("infected", 1.5)])), ("no_death_effects", True)])),
    ("festering", OD([("label", "Festering"), ("stacks", 1), ("lasts", 3.0), ("color", "9a8a50"), ("poise_regen_off", True)])),
    # water
    ("waterlogged", OD([("label", "Waterlogged"), ("stacks", 1), ("lasts", 6.0), ("color", "3a6ad0"), ("counts_as", ["soaked"]),
                        ("lighter_class", True)])),
    ("drowning", OD([("label", "Drowning"), ("stacks", 1), ("lasts", 3.0), ("color", "2a5ab0"), ("cannot_attack", True), ("no_call", True),
                     ("dps_per_stack", 15.0), ("tick_s", 0.5), ("dot_tags", ["dot", "water", "drowning"]), ("ends_after_damage", 150.0),
                     ("control", True)])),
    ("dripping", OD([("label", "Dripping"), ("stacks", 1), ("lasts", 10.0), ("color", "6aa0e0"), ("nudge_per_s", 0.4), ("poise_per_s", 8.0),
                     ("poise_regen_off", True)])),
    ("adrift", OD([("label", "Adrift"), ("stacks", 1), ("lasts", 1.5), ("color", "6aa0e0"), ("hidden", True)])),
    ("seeped", OD([("label", "Seeped"), ("stacks", 1), ("lasts", 4.0), ("color", "5080c0"), ("front_block_off", True), ("armour_mult", 0.0)])),
    ("stilled", OD([("label", "Stilled"), ("stacks", 1), ("lasts", 2.0), ("color", "80b0e0"), ("move_mult", 0.4), ("shove_mult", 2.0),
                    ("ends_on_shove", True)])),
    # lightning
    ("insulated", OD([("label", "Insulated"), ("stacks", 1), ("lasts", 6.0), ("color", "b0a0e0"), ("blocks", ["drummed", "frenzied"]),
                      ("no_conduct", True), ("no_death_effects", True)])),
    ("muted", OD([("label", "Muted"), ("stacks", 1), ("lasts", 1.0), ("color", "b8a8ff"), ("no_call", True)])),
    # earth
    ("buried", OD([("label", "Buried"), ("stacks", 1), ("lasts", 2.5), ("color", "8a6a40"), ("cannot_act", True), ("control", True),
                   ("damage_taken_mult", 0.25), ("elite_status", "pinned")])),
    # --- the 2026-10-24 v2 drafts (the 14 the v2 runes grant, and the drafts' new_mechanics) ---
    # earth / metal / unholy: one taunt. It comes for whoever put it on and nobody else; lures, decoys and thralls do not draw it
    ("taunted", OD([("label", "Taunted"), ("stacks", 1), ("lasts", 4.0), ("color", "c89a5a"), ("forced_target", "source"),
                    ("closes_in", True), ("heavy_lasts_mult", 0.5)])),
    # wind (Turning Palm, Blowout) and Metal's Deflect: spun round, its back to you
    ("turned", OD([("label", "Turned"), ("stacks", 1), ("lasts", 1.0), ("color", "bfe9dc"), ("turn_away", True), ("counts_rear", True),
                   ("heavy_lasts_mult", 0.5)])),
    # life (the Tithe rune): hits on it from whoever applied it heal them
    ("tithed", OD([("label", "Tithed"), ("stacks", 1), ("lasts", 6.0), ("color", "f2b8cc"), ("heals_attacker_frac", 0.15),
                   ("living_only", True)])),
    # death (Grave Mark, the Bid rune) and nature (the Herd rune, Unleash the Pack): one mark for your summons
    ("bidden", OD([("label", "Bidden"), ("stacks", 1), ("lasts", 6.0), ("color", "c8bf9c"), ("summons_target", True),
                   ("summon_damage_mult", 1.5), ("summon_rate_mult", 1.3)])),
    ("quarry", OD([("label", "Quarry"), ("stacks", 1), ("lasts", 6.0), ("color", "7fbf6a"), ("summons_target", True),
                   ("summon_damage_mult", 1.3)])),
    # dream (Sweet Lie, the Charm rune): it fights for you a while
    ("charmed", OD([("label", "Charmed"), ("stacks", 1), ("lasts", 5.0), ("color", "f0a8e8"), ("fights_for_source", True), ("lure_radius", 8.0),
                    ("ends_on_source_hit", True), ("heavy_lasts_mult", 0.5), ("elite_status", "dazed")])),
    # dream (Misgiving, the Doubt rune): slow to commit and half-hearted; elites keep it at half time too
    ("doubting", OD([("label", "Doubting"), ("stacks", 1), ("lasts", 6.0), ("color", "c8a8e0"), ("windup_mult", 1.5), ("deals_mult", 0.7),
                     ("heavy_lasts_mult", 0.5)])),
    # poison (Steeped Blade, the Steep rune): the dose clock runs longer once, and the bill is bigger
    ("steeped", OD([("label", "Steeped"), ("stacks", 1), ("lasts", 30.0), ("color", "7ab838"), ("adds_time", OD([("dosed", 3.0)])),
                    ("bill_mult", OD([("dosed", 1.5)])), ("ends_with", ["dosed"])])),
    # poison (Sting Dart): a barb that keeps dosing
    ("barbed", OD([("label", "Barbed"), ("stacks", 1), ("lasts", 4.5), ("color", "98c840"),
                   ("adds_status", OD([("status", "dosed"), ("stacks", 1), ("every", 1.5)])), ("ends_with", ["dosed"])])),
    # holy (Condemning Ray, the Condemn rune): Lit, and every hit on it from you or yours shores up your ward
    ("condemned", OD([("label", "Condemned"), ("stacks", 1), ("lasts", 8.0), ("color", "fff0b0"), ("counts_as", ["lit"]),
                      ("armour_mult", 0.5), ("light_radius", 1.5), ("ward_to_attacker", 4.0), ("ward_from_one", 30.0)])),
    # holy (Penitent Mark, the Penance rune): every attack it starts hurts it, and it hits you and yours softer
    ("penitent", OD([("label", "Penitent"), ("stacks", 1), ("lasts", 8.0), ("color", "e8d8a0"), ("on_attack_damage", 25.0),
                     ("deals_mult_vs_source", 0.7)])),
    # holy (Casting Out, the Exile rune): it will not come within keep_away of whoever cast it out
    ("exiled", OD([("label", "Exiled"), ("stacks", 1), ("lasts", 4.0), ("color", "fff8d8"), ("keeps_away", 4.0),
                   ("heavy_lasts_mult", 0.5), ("elites_immune", True)])),
    # unholy (the Leech and Reave runes): every hit on it from whoever applied it drains to them
    ("leeched", OD([("label", "Leeched"), ("stacks", 1), ("lasts", 6.0), ("color", "b06090"), ("drain_to_source", 0.15)])),
    # unholy (Grasping Dark, Night Charge, the Beckon rune): held on a short leash from whoever applied it
    ("leashed", OD([("label", "Leashed"), ("stacks", 1), ("lasts", 4.0), ("color", "8a5a8a"), ("leash_m", 4.0)])),
    # unholy (Torment, the Torment rune): a slow hurt that feeds whoever applied it
    ("tormented", OD([("label", "Tormented"), ("stacks", 1), ("lasts", 8.0), ("color", "a04878"), ("dps_per_stack", 8.0), ("tick_s", 0.5),
                      ("dot_tags", ["dot", "unholy", "tormented"]), ("drain_frac", 0.5), ("poise_regen_off", True),
                      ("living_only", True)])),
    # ice (Dead Calm, the Stasis rune): everything about it stops, then it comes out Stilled
    ("stasis", OD([("label", "Stasis"), ("stacks", 1), ("lasts", 2.5), ("color", "d8f0ff"), ("cannot_act", True), ("control", True),
                   ("freezes", ["all"]), ("heavy_lasts_mult", 0.5), ("elite_status", "stilled"),
                   ("on_expire", OD([("status", "stilled"), ("stacks", 1)]))])),
])

# What each status means for the enemy, one plain line in the game's voice (Brent 2026-10-23: "What
# does Masked mean?"). The emitter writes it as the status's "desc"; the game shows it with a rules
# line made from the status's keys (game/scripts/ui/status_text.gd). Written from what the game
# actually does - where a skill is simplified, only what is built. An alias (rooted) has none: it
# reads its target's. [MODEL]
STATUS_DESC = OD([
    ("soaked", "Wet through: your shoves throw it half again as far, and a Live mark on it leaps to every other Soaked enemy close by."),
    ("live", "Charged with your lightning. Each hit adds a mark; the third Overloads it - a heavy blow and a stun, and an arc to every other marked enemy near it."),
    ("stunned", "Knocked senseless: it cannot move or act, and whatever it was winding up is lost."),
    ("staggered", "Its poise broken and off its feet: it does nothing and takes more from every hit - the moment for a bare strike."),
    ("alight", "Burning in your name, harder with every stack. It catches on anyone who stands beside it, and jumps to a neighbour when it dies."),
    ("aloft", "Thrown into the air: helpless until it lands, and taking more from every hit. One too heavy to lift loses its footing instead."),
    ("frenzied", "Whipped up by a Censer-Bearer: it moves and attacks faster."),
    ("drummed", "Steadied by a Drummer's beat: it attacks faster and is harder to stagger."),
    ("roused", "Singled out by a Drummer: its next blow lands heavy, whoever throws it."),
    ("dazed", "Reeling: it takes half again as much from every hit. A Dazed enemy can be put to sleep."),
    ("silenced", "Cut off by an interrupt at full strength: it cannot start an attack or call for help."),
    ("pinned", "Held fast - by roots, settling silt or a downdraft: it can barely move."),
    ("slowed", "Hampered: it moves more slowly."),
    ("mired", "Wading through mud or standing water: it moves more slowly while it stays in it."),
    ("chilled", "Cold in its joints: slower with every stack. At five it freezes solid; an elite only turns Brittle."),
    ("frozen", "Frozen solid: it cannot move or act and most of a blow glances off - but a hard hit Shatters it. It thaws still Chilled."),
    ("brittle", "Cracked through: its next hard hit Shatters it, for heavy damage, and throws frozen shards at those beside it."),
    ("blinded", "It cannot see past a couple of metres: it cannot aim at you, and its swings only land close in front of it."),
    ("lit", "Picked out in light: the gaps in its armour show, so its guard stops half as much, and it gives off light. Light breaks a mask."),
    ("exposed", "Outlined and open: every hit on it counts as from behind, and its shield does not help."),
    ("shadowbound", "Its shadow nailed to the floor: it cannot walk, and nothing can shove or drag it - but it can still turn and swing."),
    ("rusting", "Rust eats the metal it wears: damage every second for each class of metal, and its armour is halved. Bare skin does not care."),
    ("fused", "Welded down: it moves much more slowly."),
    ("shackled", "Its arms banded in iron: it can still walk, but cannot attack."),
    ("stripped", "Its armour wrenched off: no front guard, it takes more from everything, and it no longer counts as armoured."),
    ("dulled", "Every edge it carries blunted: its blows do less and cannot stagger you."),
    ("bleeding", "Cut and bleeding, faster while it moves or swings. It drips blood pools as it goes, and dying leaves a pool and held blood for you."),
    ("sluggish", "Its heart slowed: it moves slower, takes longer to wind up its attacks, and bleeds more slowly."),
    ("choked", "Its own blood knotted in its throat: it cannot attack or call for help, and walks at half speed."),
    ("withering", "Its own life turned against it: damage every second, straight past shields and armour. Only the living wither."),
    ("spent", "Worn out: it moves and attacks more slowly. Only the living tire."),
    ("wasted", "Its body wasting: its blows do less and its poise is cut, so it staggers sooner. Only the living."),
    ("sick", "Sick to its stomach: every few seconds it retches, loses whatever it was doing and stands still."),
    ("arrested", "Its body stopped mid-change: it cannot heal, its poise does not come back, and the Life statuses on it stop running down."),
    ("hale", "Above half its health. Never put on anyone - read from its health; Life hits the Hale harder."),
    ("dying", "Below half its health. Never put on anyone - read from its health; Death hits the Dying harder."),
    ("spared", "Held back from death: nothing can bring it below 1 health, and below half health it kneels and does nothing."),
    ("rotting", "Decay in its gear and flesh: its armour and shield count for half, and lost poise does not come back."),
    ("dread", "A shade's dread: it backs away from the haunted ground and will not attack while it does."),
    ("dwindled", "Shrunk by a gall-vine: it counts one weight class lighter - shoves throw it further, Aloft can lift it - and its reach is cut."),
    ("blighted", "The wood it carries rots: its shield stops half as much, its attacks take longer to wind up, and Nature hits it harder."),
    ("asleep", "Asleep on its feet: it does nothing until a hit wakes it. A first Dream spell only Dazes; a second puts the Dazed one under."),
    ("wakeful", "Just woken: it cannot be put to sleep again yet - a sleep only Dazes it."),
    ("terrified", "Terrified of you: it turns and runs from you and will not attack."),
    ("soothed", "Hushed: it moves slower and starts no attacks. A hit snaps it out."),
    ("masked", "It wears your face: its friends close by take it for you and go for it instead of you. It does not fight back."),
    ("read", "You have read its tell: every attack it starts can be interrupted, and a hit during its wind-up staggers it."),
    ("commanded", "Sent on an errand: it walks to the spot you chose and stands there, starting nothing. A hit breaks it."),
    ("shut", "Its mind closed up: no Drummer can steady or rouse it, and it cannot call for help."),
    ("dosed", "Poison on a clock: when the clock over its head runs out, every dose in it is paid at once. More doses add to the bill, not the time."),
    ("corroded", "Acid eating its armour: each stack takes a third off its armour and shield and bares more of its flesh."),
    ("sapped", "A thread of poison drains it: it deals less damage and moves slower while the thread holds."),
    ("infected", "Sick with your disease, harder with every stack; armour keeps part of it out. Dying, it leaves a cloud that infects whoever walks in."),
    ("contained", "Its sickness sealed in: Infected on it climbs higher and burns harder, but nothing spreads from it, alive or dead."),
    ("festering", "A festering wound: its poise does not come back while it lasts."),
    ("waterlogged", "Heavy with water: it counts as Soaked, and as one weight class lighter, so a shove throws a heavy enemy as if it were light."),
    ("drowning", "Water closed over its head: it cannot attack or call for help, and takes damage until the water lets go or it has taken enough."),
    ("dripping", "It drips: every second it is nudged a little away from you and loses some poise, and its poise does not recover."),
    ("adrift", "Just moved by your water (not shown on it): Siltfall settles whatever is still Adrift."),
    ("seeped", "Water under its guard: its shield and armour count for nothing, against anyone."),
    ("stilled", "The tide hangs still: it moves slowly, and the next shove or drag on it goes twice as far - once."),
    ("insulated", "Sealed under still air: Live marks do not leap into or out of it, no Drummer or Censer can work it up, and nothing bursts or spreads from it when it dies."),
    ("muted", "A hum in its ears: it cannot drum or call for help."),
    ("buried", "Heaped over with earth: it cannot move or act, and takes only a quarter of every hit. An elite is only Pinned."),
    ("taunted", "Called out: it comes for whoever taunted it and attacks only them - an archer or a drummer walks in to fight hand to hand, and no lure, decoy or thrall draws it off."),
    ("turned", "Spun round: it faces away from you, so every hit on it counts as from behind until it turns back."),
    ("tithed", "Its life is tithed to you: every hit you land on it heals you a share of the harm. Only the living."),
    ("bidden", "Marked for your dead: every thrall of yours goes for it, hitting it harder and faster."),
    ("quarry", "Marked as the pack's quarry: your summons switch to it and hit it harder."),
    ("charmed", "Charmed: it fights for you, going for the nearest of its old friends, and they turn on it. Hit it yourself and it snaps out."),
    ("doubting", "Full of doubt: it is slow to start its attacks and its blows land half-hearted. Even an elite feels it, for a while."),
    ("steeped", "The poison has steeped in: its dose clock runs a little longer, once, and the bill it pays is half again as big."),
    ("barbed", "A barb in the flesh: every so often it works in another dose of your poison. Pulled when the doses are spent."),
    ("condemned", "Judged and shown: it counts as Lit, its guard stops half as much, and every hit on it from you or yours adds to your ward."),
    ("penitent", "Made to pay for its own violence: every attack it starts hurts it, and its blows on you and yours land softer."),
    ("exiled", "Cast out: it will not come near whoever exiled it, and backs away if it is close - though it may still shoot. Elites only stagger back."),
    ("leeched", "Leeched: every hit you land on it drains a share of the harm back to you as health."),
    ("leashed", "On a short leash from whoever cast it: it cannot go further from them than the leash allows, though it can still shoot from inside it."),
    ("tormented", "Kept failing on purpose: it hurts every second, and half of every hurt feeds whoever torments it. Its poise does not come back. Only the living."),
    ("stasis", "Held outside time: it cannot act, and nothing on it runs down while it lasts. It comes out Stilled. An elite is only Stilled."),
])

# The player's own short states (a buff each, read where it matters). quickened: Stepped Leader.
PLAYER_STATES = OD([
    ("quickened", OD([("label", "Quickened"), ("move_speed_mult", 1.2), ("recovery_mult", 0.7)])),
    # Dark's Vanish (Hungry Dark's on_kill self_unseen_s): unseen anywhere, not only in the Dark; your next hit ends it
    ("vanished", OD([("label", "Vanished"), ("unseen_anywhere", True), ("ends_on_hit", True)])),
    # the ward pool (Holy, Water's Crush, Ice Shell, Unholy's Black Shroud): not a buff, a pool on the body (Player.ward)
    ("ward", OD([("label", "Ward"), ("pool", True)])),
    # Nature's rule: standing on your own growth (never applied by a skill; read where you stand)
    ("in_the_green", OD([("label", "In the Green"), ("where", "growth")])),
    # buffs v2 skills put on you, shared with your summons by the skill's radius (their numbers are the skill's)
    ("red_frenzy", OD([("label", "Red Frenzy"), ("buff", True)])),
    ("blessed", OD([("label", "Blessed"), ("buff", True)])),
    ("absolved", OD([("label", "Absolved"), ("buff", True)])),
    ("kind_light", OD([("label", "Kind Light"), ("buff", True)])),
    ("overgrown", OD([("label", "Overgrown"), ("buff", True)])),
    ("unleashed", OD([("label", "Unleashed"), ("buff", True)])),
])

# What each player state means, in the game's voice (the same rule as STATUS_DESC). The buffs a v2 skill puts on
# you or your summons are listed too, by their buff id - their numbers are the skill's own. [MODEL]
PLAYER_STATE_DESC = OD([
    ("quickened", "Quickened: you move faster and recover from each cast sooner."),
    ("vanished", "Vanished: no enemy can see you, wherever you stand. Your next hit ends it - and is an Ambush."),
    ("ward", "Ward: a guard over your body that takes blows before your health does. A blow it wholly stops opens no wound. Every ward fills the one pool, up to its cap, and each amount fades on its own clock."),
    ("in_the_green", "In the Green: standing on your own growth, you and your beasts regrow health, are hard to shove and lose less poise."),
    ("red_frenzy", "Red Frenzy: you strike faster and harder, move faster and keep your footing - and after a few seconds it drinks your held blood. When the blood runs out it ends."),
    ("blessed", "Blessed: you and your summons near you hit harder, lose less poise, and your strikes leave enemies Lit."),
    ("absolved", "Absolved: the next hold that would land on you is turned away."),
    ("kind_light", "Kind Light: blows on you are softened, and what was taken off them comes back to you as health when it ends."),
    ("overgrown", "Overgrown: you and your beasts hit harder, lose less poise, and every hit regrows a little health."),
    ("unleashed", "Unleashed: a summon let off the leash - it hits harder and faster for a while."),
])

MERGED = OD([
    ("blinded", "one status for fire (Flashpan), light (Hard Glare), dark (Pall) and ice (Whiteout, Snow): cannot see past 2 m, "
                "ranged enemies cannot aim, melee only lands within 1.5 m in front"),
    ("unseen", "one player rule for dark (standing in Dark: unseen beyond 4 m) and light (Bent Light: unseen beyond 3 m); "
               "an enemy that cannot see you cannot aim at you or close on you"),
    ("rooted / pinned", "rooted is an alias of pinned: one hold (40% speed, 2 s unless the skill says otherwise)"),
    ("hex / smite / seize / gaze", "one kind, 'smite': an instant effect on the targeted enemy (gaze adds Dream's sight check)"),
    ("field_pulse", "one kind shared by Death (corpses) and Nature (growth patches)"),
])

# The 35 abilities the game had before this build: they keep their verse and icon (read back from abilities.json).
LEGACY_IDS = ["water_bolt", "tsunami_strike", "hydraulic_flex", "cinder_spit", "kiln_fist", "flashover", "slingstone",
              "landslide_blow", "bedrock_shove", "cutting_gust", "downdraft", "tailwind", "arc_lash", "thunderclap_palm",
              "stepped_leader", "crosscut", "raise_slab", "undertow", "riptide_lash", "backdraft", "pyre_call", "pillar",
              "tremor", "updraft", "forked_path", "dead_short", "standing_pool", "backwash", "slag_pool", "stoke", "stonehide",
              "veil", "gale_lane", "static_coat", "ground_rod"]

# The hand-made trees of the five affinities that had one before this build (design/08, Brent 2026-10-18): their
# nodes keep their tier and what they need. The emitter adds every other drafted skill.
LEGACY_TREES = OD([
    # v2 (2026-10-24): Water Bolt and Undertow are dropped and Riptide Lash is the ranged starter
    ("water", OD([("standing_pool", OD([("tier", 2), ("requires", ["riptide_lash"])])),
                  ("backwash", OD([("tier", 2), ("requires", ["hydraulic_flex"])]))])),
    ("fire", OD([("stoke", OD([("tier", 2), ("requires", ["cinder_spit"])])),
                 ("backdraft", OD([("tier", 2), ("requires", ["kiln_fist"])])),
                 ("slag_pool", OD([("tier", 2), ("requires", ["flashover"])])),
                 ("pyre_call", OD([("tier", 3), ("requires", ["backdraft", "slag_pool"])]))])),
    # v2: Bedrock Shove is the movement starter and Raise Slab is trained
    ("earth", OD([("pillar", OD([("tier", 2), ("requires", ["slingstone"])])),
                  ("raise_slab", OD([("tier", 2), ("requires", ["bedrock_shove"])])),
                  ("stonehide", OD([("tier", 2), ("requires", ["landslide_blow"])])),
                  ("tremor", OD([("tier", 3), ("requires", ["pillar", "stonehide"])]))])),
    ("wind", OD([("downdraft", OD([("tier", 2), ("requires", ["cutting_gust"])])),
                 ("veil", OD([("tier", 2), ("requires", ["crosscut"])])),
                 ("gale_lane", OD([("tier", 2), ("requires", ["tailwind"])])),
                 ("updraft", OD([("tier", 3), ("requires", ["downdraft", "gale_lane"])]))])),
    ("lightning", OD([("forked_path", OD([("tier", 2), ("requires", ["arc_lash"])])),
                      ("static_coat", OD([("tier", 2), ("requires", ["thunderclap_palm"])])),
                      ("ground_rod", OD([("tier", 2), ("requires", ["stepped_leader"])])),
                      ("dead_short", OD([("tier", 3), ("requires", ["forked_path", "static_coat"])]))])),
])

KIND_MAP = {"new:hex": "smite", "new:smite": "smite", "new:seize": "smite", "new:gaze": "smite",
            "new:field_pulse": "field_pulse", "new:summon": "summon", "new:seed": "seed", "new:grapple": "grapple",
            "new:streak": "streak"}

MOVEMENT_KINDS = ("dash", "blink", "grapple", "streak")
CLOSE_KINDS = ("melee_burst", "targeted_strike")

ICON_BY_KIND = {"projectile": "mote", "beam": "bolt", "melee_burst": "backdraft", "targeted_strike": "fist", "dash": "dash",
                "blink": "blink", "ground_zone": "pool", "self_buff": "coat_static", "delayed_blast": "pillar", "detonate": "short",
                "chain": "fork", "displace": "undertow", "prop": "wall", "rod": "rod", "smite": "sigil", "channel": "lane",
                "charge_release": "palm", "summon": "mask", "seed": "seed", "grapple": "lash", "streak": "tailwind",
                "field_pulse": "tremor"}

# The twelve data gaps (modifier-check-planned.md: "Listed as good modifiers, but the maths gives them nothing
# to act on"), filled so each named modifier has something real to act on. path -> value, applied to numbers.
GAP_FILLS = OD([
    ("crisis", OD([("on_hit", OD([("poise", 20.0)]))])),                              # + Fall (poise x1.3)
    ("doubling_step", OD([("leave_decoy.lure_radius", 8.0)])),                        # + Persist / Remember (decoy life) / Elsewhere (lure)
    ("shattered_dream", OD([("on_hit", OD([("poise", 20.0)]))])),                     # + Wake (bonus asleep; poise), + Fall
    ("sere_ground", OD([("on_hit", OD([("poise", 15.0)]))])),                         # + Blight (status blighted)
    ("funnel", OD([("on_hit", OD([("poise", 10.0)]))])),                              # + Attract (pull +1.5)
    ("sapping_tether", OD([("cost", 6.0), ("on_hit", "payload")])),                   # + Poison / Bind / Essence: cost and an on_hit
    # v2 (holy.json Abiding Guard: "the first blow that would land is refused whole ... a ranged attacker beyond it is
    # not answered"): Holy's counter refuses a shot too; Wind's and Metal's answer only blows (wind.json: "a shot does not")
    ("abiding_guard", OD([("refuses_shots", True)])),
])

# self buffs and channels: their main magnitude, scaled by a rune's power op. as "amount" (x m) or "mult" (its gap
# from 1 x m, so 0.75 -> 0.70 at x1.2); dir says which way is better for the preview.
MAGNITUDE = OD([
    ("backwash", [("melee_taken_mult", "mult", "down"), ("on_hit.shove", "amount", "up")]),
    ("stoke", [("add_reflux", "amount", "up")]),
    ("stonehide", [("move_speed_mult", "mult", "up")]),
    ("veil", [("duration", "amount", "up")]),
    ("static_coat", [("retaliate", "amount", "up")]),
    ("ice_shell", [("ward", "amount", "up"), ("on_break.damage", "amount", "up")]),
    ("muffle", [("unaware_mult", "mult", "up")]),
    ("plating", [("incoming_mult", "mult", "down")]),
    ("tourniquet", [("blood_per_wound", "mult", "down")]),
    ("long_breath", [("shed_per_blood", "amount", "up"), ("poise_mult", "mult", "up")]),
    ("knit", [("heal_per_s", "amount", "up")]),
    ("corded_muscle", [("strike_mult", "mult", "up"), ("strike_poise_mult", "mult", "up")]),
    ("fever_break", [("new_status_mult", "mult", "down")]),
    ("embalm", [("duration", "amount", "up")]),
    ("clear_eye", [("reveal_radius", "amount", "up")]),
    ("bitter_tonic", [("recovery_mult", "mult", "down"), ("move_speed_mult", "mult", "up")]),
    ("festering_hands", [("duration", "amount", "up")]),
    ("inured_blood", [("dr_per_infected", "amount", "up"), ("dr_max", "amount", "up")]),
    # channels
    ("bellows_breath", [("on_hit.damage", "amount", "up")]),
    ("spindrift", [("on_hit.damage", "amount", "up")]),
    ("deep_draught", [("on_hit.damage", "amount", "up")]),
    ("regrowth", [("sink_per_s", "amount", "up")]),
    ("sapping_tether", [("tick", "mult", "down")]),
])


def lab(hexstr):
    r, g, b = [int(hexstr[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    def lin(c):
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = lin(r), lin(g), lin(b)
    x = (r * 0.4124 + g * 0.3576 + b * 0.1805) / 0.95047
    y = r * 0.2126 + g * 0.7152 + b * 0.0722
    z = (r * 0.0193 + g * 0.1192 + b * 0.9505) / 1.08883
    def f(t):
        return t ** (1 / 3) if t > 0.008856 else 7.787 * t + 16 / 116
    return 116 * f(y) - 16, 500 * (f(x) - f(y)), 200 * (f(y) - f(z))


def check_colours(min_delta=20.0, min_l=45.0):
    """Every pair of affinity colours at least min_delta apart (CIE76), and each light enough to read on the dark UI."""
    out = []
    ids = list(AFFINITIES)
    for i, a in enumerate(ids):
        la = lab(AFFINITIES[a]["color"])
        if la[0] < min_l:
            out.append("%s is too dark (L %.0f)" % (a, la[0]))
        for b in ids[i + 1:]:
            lb = lab(AFFINITIES[b]["color"])
            d = sum((p - q) ** 2 for p, q in zip(la, lb)) ** 0.5
            if d < min_delta:
                out.append("%s and %s are too close (%.1f)" % (a, b, d))
    return out
