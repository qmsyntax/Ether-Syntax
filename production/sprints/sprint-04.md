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

## Part B — interface overhaul
See the commit that follows.
