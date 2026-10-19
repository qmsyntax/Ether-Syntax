# Crafting step 1: Rendering, Leatherwork and Smithing at band 1

Built 2026-10-18 on branch `feat/crafting-1`. **Built, not played.** This is design/11's build order item 11
(rendering + leatherwork + smithing at band 1, "the shortest chain to a usable item"), minus the sell-rule step, which
Brent withdrew. The rules are design/11 section 4; this file says what was built, what was decided while building, and
what is left.

Tags: **[B]** Brent's ruling, **[C]** read in the books (through the paraphrased notes), **[F]** fan source,
**[MODEL]** our invention, **[?]** unknown. Every person, place and item named here is original to this project.

Brent's rulings this follows (2026-10-18, design/11 section 13) [B]: go with the recommendations, balance later; **full sale
price** (the live sell rule stays); **no cap by stars** on crafting skill. Also [B] (design/01, ethertech): the world has
ether tech, so a workshop with an ether-fired furnace, power tools, signage or a phone on a counter would be in keeping;
the town is not restyled in this step.

---
## 1. What was built

| Part | Where | Tag |
|---|---|---|
| **Game data from the drafts.** `tools/items/emit_crafting_game.py` reads `design/data-drafts/items-full-v0.json` and `recipes-v0.json` and writes `game/data/crafting.json`: the rules as numbers (new `CRAFT_NUMBERS` beside the words in `tools/items/crafting_tables.py`), the three skills, their tool kinds, three stations with what their keeper sells, 20 recipes and the 24 items they need that are not live yet. The drafts stay the source of truth: re-run the emitter after they change. `GameData` adds the new items to the item list and never overrides a live id. | tools/items, game/data | [MODEL] |
| **Which recipes.** Band 1, Rendering / Leatherwork / Smithing, Plain or subcombine (no pattern book), whose output is a live item or a material or a tool of these three skills, and whose every input can be had: a remains drop, something a keeper sells, or another included recipe. That gives Rendering 3 (scraped brute hide + 2 tallow, bone meal + marrow, quench oil), Leatherwork 7 (cured hide, grip wrap, straps, Boiled Cap, Hide Bracers, Hobnailed Boots, Delver's Frame), Smithing 10 (billet, wire, folded steel, fittings, rivets, sheet, Currier's Knife, Flensing Knife, Iron Knuckles, Smith's Hammer). | crafting.json | [MODEL] |
| **The rules** (`scripts/crafting.gd`, `Crafting`): skill per craft 0-300, **no star cap** [B]; attempt window trivial - 30; success clamp(5%, 95%, 70% + (skill - trivial)/50 + 3% per tool tier above the one needed), **certain at trivial + 13**; failure: fee spent, each input back on a 50% roll (+10% per station grade above the recipe's; a field kit's own salvage, 0); skill-up only below trivial at 0.35 x sqrt(gap/25), capped 60%, halved on a failure, at most +1; **the first success of each recipe +1 for sure**; tools come back, lose a use (150 x tier) and break at 0. All numbers in `crafting.json` "rules". | scripts/crafting.gd | design/11 section 4 [MODEL] |
| **Player state**: `craft_skill`, `craft_known`, `craft_made`, `tool_uses`, saved and loaded. | player.gd | |
| **Stations as places**: a rendering block, a tanning yard (vats and a drying frame) and a forge, procedural models (`scripts/art/station_models.gd`), along the south of the square, each kept by a townsperson: Ama Thresh (renderer), Joss Calder (tanner), Hesk Varga (smith). Talk to them (F or click): **Work at the station** (the crafting screen), **Tools and supplies** (their shop), **Learn the trade** (every included recipe of their skill, for a fee: $50 / $75 / $100). | data/town.json, town_builder.gd, talk_screen.gd | [MODEL] |
| **Crafting screen** (`ui/craft_screen.gd`): the station's recipes (learned; greyed below the attempt window; marked not learned), and for the chosen one: skill and trivial, chance, station fee, tool and its uses, hours, inputs have / need, outputs and their value, why it cannot be made, Combine, and what the last combine did. | ui/craft_screen.gd | |
| **Field rendering** [B: approved, design/11 Q8]: the renderer sells a **Flensing Kit**; click it in the pack anywhere and the rendering recipes open on it - no fee, nothing back from a failure. Out of town it pauses the game, like the pack. | inventory_screen.gd, main.gd | |
| **Selling** [B]: the live rule, unchanged in its prices: gear (and scrolls) at `gear_sell_factor`, everything else in full. Tools, kits and materials are no longer swept up by the merchant's "Sell your loot" (they sell one at a time from the pack, at full value), so a crafter's stock is not sold by accident. | inventory.gd | [MODEL] the sweep |

## 2. Decisions to review (all [MODEL])

1. **Stopgap vendors.** Crucible and fitting mould (Pottery), tanning liquor (Brewing) and haft (Bowyery) are sold by the smith and
   the tanner at their draft value until those skills are built. Scrap iron and flux salt are sold too (design/11 already lists
   them as guild-vendor basics).
2. **The first success of a recipe always gives +1**, even past its trivial (rewards breadth). The design wording could be read as
   "only below trivial"; this reading was chosen.
3. **Station fee = the recipe's fee** (design/10's fee), paid on every combine; there is no separate rent. A field kit pays none.
4. **Learning the trade** is a one-off fee to the keeper for every included recipe of the skill (design/11: "known on joining
   the guild"; there is no guild yet).
5. **Only Plain and subcombine recipes.** Fine recipes need pattern books, etherwork's quench and more; and recipes that make gear
   that is not live yet (kettle helm, war maul, ...) need models and stats the game does not read yet. Both stay in the drafts.
6. **No world clock.** The game counts days (`main.day`) but has no hours, so a combine takes no game time; the recipe's `hours`
   are shown and kept in the data for when the clock exists (design/07's 90-minute day).
7. **Success station bonus is 0** (`station_grade_success`): design/11 names a "station bonus" without a number.
8. The stations stand along the south side of the square, keepers in front facing the camera. The models are plain and
   pre-ethertech (coals, not an ether furnace); a restyle for ethertech is planned separately [B].

## 3. Left for later

- The other twelve crafting skills and the five gathering skills; pattern books and Fine recipes; guild marks.
- Gear outputs that are not live items yet, with their stats and models.
- The world clock (combine hours), crafting and latent aura (Q5), the balance numbers [B: later].
- Stacking in the pack (crafting makes many small items: 9 cured hides weigh 18 kg).
- 323 draft recipes make a profit at full price (design/11 section 13): in step 1, e.g. a scraped hide ($450) from a brute hide
  ($500) is not one, but the chain as a whole was not audited for profit. Balance is for later [B].

## 4. What was and was not checked

Checked by tests (see the session report for the runs): the self-test `_test_crafting` (the data and every rule: attempt
window, success curve and clamp, certainty past trivial + 13, half back on failure, skill-ups only below trivial, the first
success, no star cap, tool wear and breaking, kit fee and salvage, sale prices, teaching, save/load) and
`_test_crafting_town` (render a brute hide, tan it, smelt, make Iron Knuckles and wear them, sell a made billet at full value,
render on a kit in the field); `ui_click_probe` clicks the smith, Learn the trade, Work at the forge, a recipe and Combine.

**Not checked - needs Brent**: how crafting feels; whether the station row reads well from the game camera; whether the
numbers (fees, skill-up rate, 9 hides from one tanning) are sensible; whether the stopgap vendors make the chain too easy.
