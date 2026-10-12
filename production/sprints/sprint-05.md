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
A sub-agent is building `game/scripts/art/` (ModelRig, Models) as new files only; integration follows its report.
