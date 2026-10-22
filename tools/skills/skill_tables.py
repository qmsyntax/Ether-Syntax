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

AFF_ORDER = ["water", "fire", "earth", "wind", "lightning", "ice", "dark", "metal", "blood", "life", "death",
             "nature", "light", "dream", "poison", "disease"]

# Existing affinities keep every key they had. New ones: label, colour, desc (from the draft rule) and the
# rule's data keys. Keys are documented in game/data/affinities.json's _note (written by the emitter).
AFFINITIES = OD([
    ("water", OD([("label", "Water"), ("color", "2f7fd6"),
                  ("desc", "You decide where everyone stands. Every skill shoves, and what is shoved into something breaks on it."),
                  ("marks_adrift", True)])),
    ("fire", OD([("label", "Fire"), ("color", "e2632a"),
                 ("desc", "You get hotter, and so does everything near you. Your own heat is your damage - right up to the moment it locks."),
                 ("damage_per_reflux", 0.6), ("reflux_shed_mult_combat", 0.5)])),
    ("earth", OD([("label", "Earth"), ("color", "a8824a"),
                  ("desc", "Slow, heavy and sure. You raise stone, stand behind it, and break it over whoever is on the other side."),
                  ("stone", True), ("reflux_shed_mult", 0.5)])),
    ("wind", OD([("label", "Wind"), ("color", "9fd6c4"),
                 ("desc", "You are only dangerous while you are moving. Run and the pips fill; stand to think and they drain."),
                 ("slipstream", True), ("reflux_shed_mult_moving", 3.0), ("reflux_shed_mult_standing", 0.0), ("rear_bonus", 0.5)])),
    ("lightning", OD([("label", "Lightning"), ("color", "c9b5ff"),
                      ("desc", "One target, three touches, gone. Its heat does not bleed off in a fight - only finishing a target grounds it."),
                      ("reflux_shed_mult_combat", 0.0)])),
    # --- new (2026-10-22 drafts) ---
    ("ice", OD([("label", "Ice"), ("color", "7fd8ff"),
                ("desc", "Cold stays. Lay Chill over several casts until they lock solid, then break them with one hard hit.")])),
    ("dark", OD([("label", "Dark"), ("color", "9a6bd1"),
                 ("desc", "Strongest where the light is weakest. Make your own dark, stand in it unseen, and hit them while they stand in it."),
                 ("light_mult", OD([("dark", 1.25), ("lit", 0.8)])), ("unseen_in_dark", True)])),
    ("metal", OD([("label", "Metal"), ("color", "b8c2cc"),
                  ("desc", "You work the metal that is already there: armour is your target, and your weapon is your material."),
                  ("per_metal_class", 0.25), ("through", True)])),
    ("blood", OD([("label", "Blood"), ("color", "d23a48"),
                  ("desc", "You work blood that is already out: open Bleeding, ride and drink the pools, spend what you hold. Never your own health."),
                  ("held_blood", True)])),
    ("life", OD([("label", "Life"), ("color", "f29ab8"),
                 ("desc", "Inside living bodies: past armour and shields, hardest on the hale, nothing to the unliving. It mends you fast but wounds slowly."),
                 ("through", True), ("living_only", True), ("hale_mult", 1.25)])),
    ("death", OD([("label", "Death"), ("color", "ddd3b4"),
                  ("desc", "What has died stays useful: corpses lie longer for you and your skills spend them, and the Dying take more."),
                  ("dying_mult", 1.3), ("corpse_lie_s", 20.0)])),
    ("nature", OD([("label", "Nature"), ("color", "4fae5a"),
                   ("desc", "Plant growth that stays, spreads and grows stronger with age; then feed it or cash it in.")])),
    ("light", OD([("label", "Light"), ("color", "ffd866"),
                  ("desc", "Light arrives at once along a straight line and stops on the first opaque thing; whatever it touches is Lit.")])),
    ("dream", OD([("label", "Dream"), ("color", "e58ae0"),
                  ("desc", "Takes hold only of a mind that can see you, or one asleep. Past armour and shields, harder on the Dazed and the Asleep."),
                  ("needs_seen", True), ("through", True),
                  ("bonus_vs_status", OD([("dazed", 0.3), ("asleep", 0.3)])),
                  ("status_time_vs", OD([("dazed", 1.5), ("asleep", 1.5)]))])),
    ("poison", OD([("label", "Poison"), ("color", "a8e04a"),
                   ("desc", "Doses in one body: the first starts a 6 s clock, the rest add to the bill, and the clock pays it all at once.")])),
    ("disease", OD([("label", "Disease"), ("color", "9fa848"),
                    ("desc", "Lives in clouds that linger and drift; flesh inside catches it. Armour cuts it, shields and facing do not."),
                    ("times_flesh", True), ("through", True)])),
])

# reflux tier -> reflux_per_cost when a draft gives none (design/05 cost tiers: low 0.4-0.7, middling 1.0, high 1.4)
REFLUX_TIER = {"low": 0.7, "middling": 1.0, "high": 1.4}

# Rule numbers that belong to one affinity but are read by the shared systems (game/data/affinities.json).
AFFINITY_RULE_NUMBERS = OD([
    ("blood", OD([("held_blood_max", 10), ("held_blood_thin_s", 5.0), ("held_blood_per_bleeding_kill", 2),
                  ("pool", OD([("radius", 0.5), ("life", 15.0), ("max", 12), ("death_radius", 1.0), ("death_measures", 3)]))])),
    ("nature", OD([("growth", OD([("radius", 1.0), ("ages", [5.0, 15.0]), ("age_mult", [1.0, 1.5, 2.0]), ("spread_every", 5.0),
                                  ("max", 12), ("bramble", OD([("tick_s", 1.0), ("payload", OD([("damage", 6.0), ("status", "slowed")]))])),
                                  ("snarevine", OD([("tick_s", 4.0), ("payload", OD([("status", "rooted")]))]))]))])),
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
])

# The player's own short states (a buff each, read where it matters). quickened: Stepped Leader.
PLAYER_STATES = OD([
    ("quickened", OD([("label", "Quickened"), ("move_speed_mult", 1.2), ("recovery_mult", 0.7)])),
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
    ("water", OD([("undertow", OD([("tier", 2), ("requires", ["water_bolt"])])),
                  ("riptide_lash", OD([("tier", 2), ("requires", ["tsunami_strike"])])),
                  ("backwash", OD([("tier", 2), ("requires", ["hydraulic_flex"])])),
                  ("standing_pool", OD([("tier", 3), ("requires", ["undertow", "riptide_lash"])]))])),
    ("fire", OD([("stoke", OD([("tier", 2), ("requires", ["cinder_spit"])])),
                 ("backdraft", OD([("tier", 2), ("requires", ["kiln_fist"])])),
                 ("slag_pool", OD([("tier", 2), ("requires", ["flashover"])])),
                 ("pyre_call", OD([("tier", 3), ("requires", ["backdraft", "slag_pool"])]))])),
    ("earth", OD([("pillar", OD([("tier", 2), ("requires", ["slingstone"])])),
                  ("bedrock_shove", OD([("tier", 2), ("requires", ["landslide_blow"])])),
                  ("stonehide", OD([("tier", 2), ("requires", ["raise_slab"])])),
                  ("tremor", OD([("tier", 3), ("requires", ["pillar", "bedrock_shove"])]))])),
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

# duplicate ids across drafts: (affinity, draft id) -> (new id, new name)
RENAMES = {("disease", "fever_break"): ("crisis", "Crisis")}

# The twelve data gaps (modifier-check-planned.md: "Listed as good modifiers, but the maths gives them nothing
# to act on"), filled so each named modifier has something real to act on. path -> value, applied to numbers.
GAP_FILLS = OD([
    ("hammering_heart", OD([("on_hit", OD([("poise", 10.0)]))])),                     # + Choke (interrupts; status choked)
    ("crisis", OD([("on_hit", OD([("poise", 20.0)]))])),                              # + Fall (poise x1.3)
    ("doubling_step", OD([("leave_decoy.lure_radius", 8.0)])),                        # + Persist / Remember (decoy life) / Elsewhere (lure)
    ("shattered_dream", OD([("on_hit", OD([("poise", 20.0)]))])),                     # + Wake (bonus asleep; poise), + Fall
    ("sere_ground", OD([("on_hit", OD([("poise", 15.0)]))])),                         # + Blight (status blighted)
    ("funnel", OD([("on_hit", OD([("poise", 10.0)]))])),                              # + Attract (pull +1.5)
    ("sapping_tether", OD([("cost", 6.0), ("on_hit", "payload")])),                   # + Poison / Bind / Essence: cost and an on_hit
])

# self buffs and channels: their main magnitude, scaled by a rune's power op. as "amount" (x m) or "mult" (its gap
# from 1 x m, so 0.75 -> 0.70 at x1.2); dir says which way is better for the preview.
MAGNITUDE = OD([
    ("backwash", [("melee_taken_mult", "mult", "down"), ("on_hit.shove", "amount", "up")]),
    ("stoke", [("add_reflux", "amount", "up")]),
    ("stonehide", [("move_speed_mult", "mult", "up")]),
    ("veil", [("duration", "amount", "up")]),
    ("static_coat", [("retaliate", "amount", "up")]),
    ("ice_shell", [("absorb", "amount", "up"), ("on_break.damage", "amount", "up")]),
    ("muffle", [("unaware_mult", "mult", "up")]),
    ("plating", [("incoming_mult", "mult", "down")]),
    ("tourniquet", [("blood_per_wound", "mult", "down")]),
    ("long_breath", [("shed_per_blood", "amount", "up"), ("poise_mult", "mult", "up")]),
    ("knit", [("heal_per_s", "amount", "up")]),
    ("corded_muscle", [("strike_mult", "mult", "up"), ("strike_poise_mult", "mult", "up")]),
    ("fever_break", [("new_status_mult", "mult", "down")]),
    ("embalm", [("duration", "amount", "up")]),
    ("clear_eye", [("reveal_radius", "amount", "up")]),
    ("bent_light", [("duration", "amount", "up")]),
    ("bitter_tonic", [("recovery_mult", "mult", "down"), ("move_speed_mult", "mult", "up")]),
    ("festering_hands", [("duration", "amount", "up")]),
    ("inured_blood", [("dr_per_infected", "amount", "up"), ("dr_max", "amount", "up")]),
    # channels
    ("pressure_jet", [("on_hit.damage", "amount", "up")]),
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
