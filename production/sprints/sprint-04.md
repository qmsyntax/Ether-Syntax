# Sprint 04 — Inventory, loot, shop, saving (logic), then the interface overhaul

> 2026-10-11. Roadmap sprint 3a, plus Brent's request the same day for a much better GUI. Split in two so the
> rules are tested and committed before any screen is drawn on top of them.

## Part A — logic (this commit)
| # | Story | Evidence | Status |
|---|-------|----------|--------|
| S04-1 | `items.json`: backpacks, satellites, trinkets, loot, shop list, exit-reward table (all original) | selftest | Done |
| S04-2 | `Inventory`: bag by weight, slots back / satellite / trinket, equip with overload refusal, sell loot, serialise | selftest | Done |
| S04-3 | Satellites are items: the free one is gone; a 1-star wears a 2-star satellite at full rate; trinkets change cost and reflux shed | selftest | Done |
| S04-4 | Ground loot: enemies drop pickups; click one to walk over and take it (enemy > loot > scenery when picking); too heavy stays put | selftest | Done |
| S04-5 | Exit rewards scaled to walls cleared; town sell / buy on credit / rest as callable logic | bots + selftest | Done |
| S04-6 | `SaveGame` (user://save.json): written on reaching town, Continue on the select screen, deleted on hardcore death | selftest round trip | Done |

Verified: self-test 102/102 (21 new), smoke, three bots with unchanged payouts.
Not verified: any of it by hand. Town buying has no screen yet (keys only: 3 sells, C continues) - Part B builds it.

## Part B — interface overhaul (Brent, 2026-10-11: "it needs to feel like a dungeon crawler")
| # | Story | Evidence | Status |
|---|-------|----------|--------|
| S04-7 | `UiTheme` (stone / bronze / parchment palette, serif type, one Theme for all controls), `UiDraw` (liquid orbs, ring gauges, bars, glyph icons), `UiWidgets` | screenshots | Done |
| S04-8 | HUD: health orb (three wound layers as stacked bands) with a striking-arm ring; essence orb with a reflux ring that heats and locks; action bar with icons, keys, costs, stage pips, progress and a pulsing "needs a construct" frame; star-growth bar | `ui-hud.png`, `ui-hud-low.png` | Done |
| S04-9 | Target frame, floating enemy health bars, wall / wave announcements, fading message log, character plate, prompt strip, low-health vignette and hurt flash | screenshots | Done |
| S04-10 | Tooltips for skill slots and both orbs; passage tracker (one pip per wall, exit marker, money banked); loot names on the ground | `ui-hud.png` | Done |
| S04-11 | Screens with clickable controls: talent cards (verse, rule, two-star evolution, one thing still unproven), town (services + ledger), merchant, inventory (worn / pack / abilities with per-ability bind buttons), controls menu restyled, death screen | `ui-title/town/shop/inventory/controls.png` | Done |
| S04-12 | UI scales with the window (canvas_items stretch); clicks on HUD panels are not attack orders; Esc backs out of merchant and inventory | headless UI runs clean | Done |

Bug found and fixed on the way: `set_anchors_preset` preserves the control's current (zero) size, which collapsed the
whole interface into the top-left corner; `set_anchors_and_offsets_preset` is the right call.

Verified: self-test 102/102, smoke, three bots, every UI state runs headless with no errors, and each screenshot was
inspected. Not verified: any of it under a real mouse - button clicks, tooltips following the cursor, scrolling,
window resizing, and whether the layout holds at other resolutions.
