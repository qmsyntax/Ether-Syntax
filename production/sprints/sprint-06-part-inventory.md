# Sprint 06, part — the inventory as a paper doll

Asked for by Brent 2026-10-12: "lets get the inventory to match EQ style inventory screen showing slots for each
piece etc." Built on branch `feat/inventory-doll`. Design: `design/06-loot-and-equipment-v0.md` section 2 (approved).

| # | Story | Evidence | Status |
|---|-------|----------|--------|
| INV-1 | `Inventory.SLOTS` is the twelve approved slots: weapon (main hand, id kept), offhand, ranged, head, body, hands, feet, back, belt, satellite, trinket, trinket2. `trinket2` takes any `trinket` item; the same item is never worn twice; `equip(id, into)` names a slot | selftest | Done |
| INV-2 | Saves: the twelve slots round-trip; a save from before loads with the new slots empty; a slot or piece a save names that does not fit is dropped, not worn | selftest | Done |
| INV-3 | The screen: character sheet on the left, the figure (live 3D, turnable, holding the equipped weapon) in the middle with six labelled slots either side, the pack as a 7-wide grid on the right. Empty slots show a dim ghost glyph and "empty" | `--shot-ui=inventory` at 1600x900 and 1280x720, looked at | Done |
| INV-4 | The sheet reads the player: name, prime, affinities, stars and newest star's growth, health, wounds, armour, strike damage, reach, ranged damage and interval, essence regeneration, ability cost and reflux shedding from gear, carried / capacity, purse | screenshot; numbers checked by hand against the kit worn in it | Done |
| INV-5 | A description panel under the pack follows the cursor (pack item or slot), keeps the last thing, compares a pack piece stat by stat with what is worn where it would go, and carries the Sell / Drop / Take off button. It has its own place, so it never covers anything | `compare_lines` in selftest; panel in the screenshot | Done |
| INV-6 | Interactions kept: left-click and right-click equip, drag onto a slot equips, loot is not clickable. New: click a worn piece to take it off, drag onto a named slot (second trinket) fills that slot, drop on the figure wears it | `ui_click_probe` in town and paused in the field (17 checks each); the drop-on-figure path is NOT covered by it | Done |
| INV-7 | Abilities and constructs moved to a second tab of the right panel; the tab says how many abilities have a construct waiting | `--shot-ui=inventory-abilities` | Done |
| INV-8 | Ten live items for the new slots (two each), five of them in the shop; a new character also starts in Street Boots and a Rope Belt | selftest | Done |
| INV-9 | `ranged_interval_mult` is read (`Player.ranged_interval`), so the Quiver Belt does what it says | selftest (fires a shot and reads the wait) | Done |

## Items brought over from the draft catalogue, and what was left off them

Only stats the game reads are on the live items (the self-test now fails if any live item lists another).

| Item | Slot | On the live item | In the draft but left off, and why |
|------|------|------------------|-------------------------------------|
| Oilcloth Hood | head | armour 1, reflux_shed_mult 1.03 | - |
| Boiled Cap | head | armour 2 | wound_resist 3: nothing reads wound resistance |
| Work Gloves | hands | armour 1 | - |
| Hide Bracers | hands | armour 2 | wound_resist 2 |
| Street Boots (starting) | feet | armour 1 | - |
| Hobnailed Boots | feet | armour 2 | wound_resist 2, poise 4: the player's poise is not a gear stat yet |
| Chalk Slate | offhand | cost_mult 0.96 | - |
| Runesetter's Slate | offhand | cost_mult 0.93 | - |
| Rope Belt (starting) | belt | nothing | quick_slots 1: there are no quick slots or consumables. It says "Does nothing yet." |
| Quiver Belt | belt | ranged_interval_mult 0.96 (wired this sprint) | quick_slots 1, ammo_recover_add 0.15: no quick slots, no ammunition |

Not brought over at all: shields (their whole effect is `block`, which is not built - so the off hand holds slates
only), the Clay Sump (`reflux_gain_mult` is not read), Kid Gloves and Soft Runners (their point is
`melee_cooldown_mult` on a glove, which `weapon_stat` does not read off the main hand, and `move_speed_mult`).

## Things that changed besides the screen

- A new character has 3 armour (coat 2, boots 1) where it had 2. `_bare()` in the self-test now strips every
  armour piece, and `_test_gear_step_1` takes the boots off before its exact-number checks (two added lines).
- The item id for the off hand is `offhand` (design/06 writes `off_hand`; the draft catalogue will need the same
  spelling when more of it comes over).
- Wearing a duplicate of something already worn is refused ("you already wear one"), whichever slot is named.

## Not done / not tested

- Not hand-played. Whether the layout reads well in use, and whether hover-then-click for Sell / Drop is
  comfortable, needs Brent.
- The figure shows the weapon and a missing arm, because that is all the model can show. Armour, hood, boots,
  off-hand and ranged pieces are not drawn on it.
- Two-handed weapons, consumables, quick slots, worn-weight limits, tiers and item colours are out of scope.
- The screen does not re-flow if the window is resized while it is open (it does not need to at 16:9; the canvas
  is scaled). Ultra-wide or 4:3 windows were not looked at.
- `FigureView` repeats the creation screen's turntable set-up rather than sharing it; the creation screen was left
  alone so its probe could not be disturbed.
- The shop is still one long list; the five new pieces are below the fold.
