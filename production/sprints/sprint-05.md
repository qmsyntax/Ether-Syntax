# Sprint 05 — Ethercosm screen, and procedural character art

> 2026-10-11. Roadmap sprint 3b (systems index #43 Ethercosm Screen, #44 Hotbar assignment).

## Part A — the ethercosm
| # | Story | Evidence | Status |
|---|-------|----------|--------|
| S05-1 | `ethercosm_screen.gd`: stars at the centre sized by capacity with a capacity ring; satellite in orbit; abilities around them, each in a ring of 16 runes that light with progress; completed stages close into gold rings with the bound construct set in as a gem; a full ring waiting for a construct pulses; three empty spirit-ability sockets | `shots/ui-ethercosm.png`, `ui-ethercosm-2.png` | Done |
| S05-2 | Click an ability: details, bind buttons for matching constructs, and skill-slot buttons | screenshots | Done |
| S05-3 | `Player.assign_slot` / `unassign_ability` (an ability lives on one slot; moving onto an occupied slot swaps); arrangement is saved | selftest (7 checks) | Done |
| S05-4 | Key K (rebindable), a town button, HUD hint, Esc closes; pauses in the field | headless run clean | Done |

Canon vs ours: the ethercosm as the soul's inner space, stars as tanks, satellites, runes as what defines an ability
and runechains as the part that grows are from the books (design/01 LAW 2, 4c). The glyph shapes, the 16-rune ring
and the layout are ours. The books' own rune names are deliberately not used.

Verified: self-test 109/109, smoke, three bots, screenshots inspected. Not verified: clicking abilities and buttons
with a real mouse.

## Part B — procedural character models
There is no image generator in this toolchain, so the art is built in code. A sub-agent wrote the library as new
files only; the integration into gameplay scripts was done afterwards in the main session.

| # | Story | Evidence | Status |
|---|-------|----------|--------|
| S05-5 | `ModelRig` (named parts baked to ~a dozen draw calls per character; highlight, hit flash, wind-up tint, hide a part, dead look, procedural walk / strike animation) and `Models` (player, three enemies, grass, bush, two loot objects) - all original designs | `shots/art-close.png`, `art-preview.png` | Done (sub-agent) |
| S05-6 | Player, enemy, scenery and pickup scripts own a rig instead of a capsule; enemies turn to face you and telegraph with the rig; the player's lost arm is hidden on the model; a revive rebuilds the body | selftest, bots, click test, `ui-hud.png` | Done |
| S05-7 | Camera zoom moved to data and brought in from 24 to 19 so the models read | screenshots | Done |

Known rough edges (from the sub-agent's own report): grass is low-contrast on the golden floor; the lost arm reads
mainly through the missing gauntlet; the commander's banner overlaps its crest; the brute's fists poke slightly past its
gameplay radius. Animation has only been seen as still frames - the walk cycle, cloth sway and strike blend are untested
in motion.
