# UI review v0 — the whole interface against BG3 / Diablo 4, and the optimized version

Draft of 2026-10-18, branch `feat/ui-v2`. Sections 1–2 are the review of the interface as it stood at commit `70a0f92`;
section 3 is the optimized design; section 4 is what was built from it (HUD and the in-scope screens); section 6 is what Brent
has to decide. **Nothing here has been played with hands on the controls** — see section 7.

Tags: **[B]** Brent's ask or ruling, **[MODEL]** our proposal, **[?]** unknown. Anything untagged inside a section headed
[MODEL] is [MODEL]. No book text, names or art are involved; the interface's words are the game's own.

Asked for by Brent 2026-10-18 [B]: *"give an agent the task of reviewing the entire UI display and coming up with an optimized
version."* Context [B]: the game should look and feel like Baldur's Gate 3 / Diablo 4 — grounded, not cartoonish — and the
characters are now realistic 3D models.

Out of scope (another agent is rebuilding them): the town screen (`ui/town_screen.gd`), the town level, skill training, a skill
tree screen, the creation screen's skill-pick step. They are only touched here through the shared theme (fonts, frames, button
styles), which every screen inherits.

Contents: 1 How it was reviewed · 2 Findings per screen · 3 The optimized design · 4 What was built · 5 Before and after ·
6 Decisions for Brent · 7 What was and was not tested

---
## 1. How it was reviewed

Every UI state the game can screenshot (`--shot-ui=<mode>` in `main.gd`, plus `--shot-settings`) was captured at the reference
size 1600 x 900 and the HUD and inventory again at 1920 x 1080, then looked at one by one. States: `title` (= creation step 1),
`create-1..4`, `create-2-face`, `town`, `shop`, `saves`, `inventory`, `inventory-abilities`, `ethercosm`, `ethercosm-2`, `temper`,
`settings`, `hud`, `hud-low`, `hud-dual`, `nether`, `enemies4`, `combat`, `skills`, `fire`, `wind`, `earth`, `stubble`,
`stubble-cut`. The "before" set is `shots/ui-v1-<state>.png`, the "after" set `shots/ui-v2-<state>.png` (`shots/` is not in git;
both sets sit in the branch's worktree, see section 5).

Judged against BG3 / D4 on: readability at 1600 x 900 and 1920 x 1080, information hierarchy, clutter, consistency of type,
colour and frames, what the player needs in combat versus out of it, hit-target sizes, feedback (damage, cooldowns, wounds,
reflux) and the minimap. The window uses `canvas_items` stretch, so 1920 x 1080 is the 1600 x 900 layout scaled by 1.2 — the
layout is the same at both; only the absolute pixel sizes of text change (a 12 px caption becomes 14.4 px).

---
## 2. Findings per screen [MODEL]

Severity: **high** = misreads or unreadable in play; **med** = slows the player down or looks unfinished; **low** = polish.

### 2.1 HUD — in combat (`ui-v1-hud.png`, `ui-v1-hud-low.png`, `ui-v1-hud-dual.png`, `ui-v1-fire.png`)
1. **high — text drawn straight onto the world is unreadable on bright ground.** Everything floating over the world used 11–13 px
   type with a 1 px drop shadow: the labels over the orbs (`arm 62%`, `satellite +1/s`, `reflux 63 - costs more`), the fire heat
   bonus (`fire +43%`, `ui-v1-fire.png`) — a number fire players fight by — the Slipstream / stone labels, the star line, the key
   reminders and the log. On the scrubland and Stubble floors several of these vanish.
2. **high — the orbs' "of 100" / "of 58" sit red-on-red and blue-on-blue** at 12 px; the current value is fine, the maximum (which
   is what wounds change) is not legible.
3. **med — the dock's information has no hierarchy.** Six labels hover over the two orbs at once whether or not anything is wrong
   (`no satellite`, `reflux 0`, `arm 100%`); the warning that matters (LOCKED, slow to recover) has to compete with them.
4. **med — no recovery / cooldown feedback.** A cast puts every skill into a recovery (`cast_recovery`, longer when running hot),
   the strike has its own cooldown and the sling a reload, and none of it is drawn. D4 sweeps the slot.
5. **med — the basic strike and the shot are not on the bar.** They are the two most-pressed actions and their bindings (LMB,
   Shift) appear only in a faint text line at the bottom right.
6. **med — slot internals collide.** The key number (top left, 12 px), the cost (bottom right, 12 px) and the progress bar share
   58 px; the cost overprints the progress bar; empty slots are featureless black squares.
7. **low — the star line's labels overlap the slab's top edge** and the right-hand aura text is cut by the essence orb.
8. **low — the slot tooltip floats high above the bar**; fine, but its body text is 13 px.

### 2.2 HUD — out of combat (`ui-v1-stubble.png`, `ui-v1-stubble-cut.png`, `ui-v1-combat.png`)
1. **high — the key reminders and pack weight (bottom right)** are 13 px `TEXT_FAINT` on the ground: unreadable on the Stubble.
   They also run under the essence orb at 1600 x 900 (`Shift shoot` touches its ring).
2. **med — the message log** has no backing; long lines run under the health orb (`ui-v1-hud-dual.png`).
3. **med — the prompt strip** writes key names as `[Space]` text; it reads, but a keycap reads faster (BG3 / D4 both chip keys).

### 2.3 Minimap and passage tracker (`ui-v1-stubble.png`, `ui-v1-hud.png`)
1. **high — the fog is near-black (96%),** so at 4% explored the minimap is a black rectangle with one smudge; it reads as a
   broken panel, not a map. D4 / BG3 keep the unexplored area a dark map tone.
2. **med — the caption under it** (`The Stubble`, `4% explored`) is drawn on the world at 10–13 px: unreadable on bright ground.
3. **low — no north marker.**
4. **low — the passage tracker's `exit` label** is 10 px.

### 2.4 Over the world (`ui-v1-enemies4.png`, `ui-v1-combat.png`, `ui-v1-skills.png`, `ui-v1-nether.png`)
1. **med — enemy health bars are 5 px and poise bars 3 px**; fine as a glance, but the hovered target's poise (the gauge that
   leads to an Opening) is not in the target frame at all.
2. **med — the target frame's `145 / 240`** is 11 px over the red bar.
3. **low — telegraph outlines** (slam circle, sweep cone, aim line) have no dark under-stroke, so on pale ground they thin out.
4. **low — floating combat numbers** use the engine's default sans font (`Label3D` with no font set) — the only non-serif type in
   the game besides the pickup labels — and a word (`OPENING`) is as big as the number it explains.
5. **low — the Netherecho title collided with a world label** (`THE NETHERECHO` over `Remnant of Piercing`, `ui-v1-nether.png`);
   wisp labels are 11 px.
6. **noted, not changed — pickup labels** (`Brute Tusk`, `Serrated Dagger`) are drawn by `pickup.gd` in the engine sans font,
   outside this task's files. One line there (set `font = UiTheme.font(true)`) would match them up.

### 2.5 Character plate (top left, every state)
1. **high — it draws over the menu screens.** The inventory sheet, ethercosm, shop, tempering yard and saves screen all sit on top
   of a plate that repeats what they show; its edge shows through at the inventory's top left (`ui-v1-inventory.png`).
2. **low — flat panel with a 2 px bronze line**; consistent but plain next to BG3's framed panels.

### 2.6 Inventory paper doll (`ui-v1-inventory.png`, `ui-v1-inventory-abilities.png`, 1920: `ui-v1-inventory-1920x1080.png`)
The structure is already right (sheet | doll with slot columns | pack + description), and it is the best screen in the game.
1. **med — every loot item is the same crate glyph**, so a pack of tusks, plates, cords and sigils is a grid of identical boxes.
2. **med — the abilities tab** stretches each ability's icon into a tall black strip, tints every icon essence-blue whatever the
   affinity, and its bind buttons use the 17 px default (they shout over the ability names).
3. **med — bar captions** (`30 of 38 kg  loot worth $2175`, `64%  costs 11 essence`) are 13 px with a 1 px shadow centred over the
   fill boundary: half the text sits on bronze or blue.
4. **low — the sheet's groups** are separated by bare rules; headings would let the eye jump (BG3's sheet is grouped).
5. **low — slot names are 11 px `TEXT_FAINT`** (under 3:1 contrast on the panel).

### 2.7 Ethercosm (`ui-v1-ethercosm.png`, `ui-v1-ethercosm-2.png`)
Strong as it is. **med** — the star bar caption is unreadable on the lavender fill; **low** — the plate peeks out behind it.

### 2.8 Shop, tempering yard, saves, message (`ui-v1-shop.png`, `ui-v1-temper.png`, `ui-v1-saves.png`)
1. **med — saves:** slots are bare text rows with no separation, buttons of different widths, and half the panel empty.
2. **med — tempering:** the bar caption `stage 0 - 50%` is split across the fill boundary.
3. **low — all four:** the plate shows through; the HUD's earth stone readout (`□□□ stone`) floats over the town under the yard.

### 2.9 Controls menu (`ui-v1-settings.png`)
**med** — one long list of 25 actions in a narrow panel; the last rows are below the fold, nothing is grouped, so finding
"Bind a construct" means scrolling past six ability slots.

### 2.10 Character creation (`ui-v1-create-1..4.png`) — theme only
Reads well; it inherits the flat panel and button styles. Its own layout is outside this task.

### 2.11 Across the board
1. **One font, one weight.** Palatino (system serif) everywhere, never bold: numbers in orbs and names in frames have no weight
   to them.
2. **No type scale.** Sizes 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 21, 22, 24, 26, 28, 30, 44 and 46 are all in use.
3. **`TEXT_FAINT` (`6d6455`) is below 3:1 on the panel colour** — used for hints and secondary lines at 11–13 px.
4. **Flat frames.** Every panel is a `StyleBoxFlat` with one bronze line; BG3 / D4 frames have a bevel, a dark outer edge and
   corner work. The look is consistent but reads "prototype".

---
## 3. The optimized design [MODEL]

### 3.1 Principles
1. **Anything drawn on the world is outlined, never just shadowed** (`UiDraw.outlined`: a dark outline about 0.28 x the type
   size). Text on a panel stays plain.
2. **Say it only when it matters.** Orb tags appear only for a warning (arm hurt or lost, reflux past `pain_at` / `burn_at`,
   LOCKED, fire's heat bonus, meditating). The calm state is the rings, which are always there.
3. **Combat shows combat.** The key reminders fade out while `in_combat` (`balance.json` "hud".`hints_alpha_in_combat`);
   an over-full pack is still said. Menus hide the plate, hints, log, tags, buffs and tracker (`UiScreen.hud_hides`), keeping
   only the dock.
4. **One frame family.** Nine-patch textures generated from scratch (`tools/assets/make_ui_textures.py`): a panel with a bronze
   bevel and corner brackets, a plain inner panel, a violet Netherecho panel, four button states and a sunken slot well. If a
   texture is missing, the old flat style is used.
5. **Rebinding-aware everywhere.** Every key shown is `Keybinds.binding_text()`; "[Key]" in a prompt is drawn as a keycap.

### 3.2 Type scale and palette
| Role | Size (px at 1600 x 900) | Use |
|---|---|---|
| `FS_DISPLAY` | 46 | announcements (WALL 3, THE NETHERECHO) |
| `FS_TITLE` | 30 | screen titles |
| `FS_HEAD` | 20 | panel headings, plate name |
| `FS_BODY` | 16 (buttons 17) | body text, prompts |
| `FS_SMALL` | 14 | tooltips, log, secondary lines |
| `FS_CAPTION` | 12 | the floor: slot keys, section heads, map captions — only on a panel or outlined |

Orb values are 28 px **bold** (a second `SystemFont` at weight 700). Palette unchanged except `TEXT_DIM` `9c917b → a69b84` and
`TEXT_FAINT` `6d6455 → 857a66` (about 4:1 on the panel), plus `NETHER` and `OUTLINE`.

### 3.3 HUD layout (1600 x 900; everything scales with the window)
```
+--------------------------------------------------------------------------------------------------+
|[PLATE 300 x 92+]                      [TARGET FRAME 380 x 62]                  [MINIMAP 300 + frame]|
| Name           o o                    name ............ (statuses)             | N              | |
| Talent                                [=====health 145/240=======]             |   map / fog    | |
| $ money  where                        [------poise---------------]             |________________| |
| <> <> 2 to bind [B]                                                            The Stubble  4%  |
|                             ~~ prompt band, keys as keycaps: [Space] go now ~~                    |
|                                                                                                  |
|                          ------------  W A L L   3  ------------  (soft shade, no band)           |
|                                                                                                  |
|                                     (world: bars, statuses, telegraphs)                         |
|                                                                                                  |
|                                                        [ARM 62%]              [REFLUX 82 · slow] |
| log (soft shade, wraps                [buff chips]   [ooooooo SLIPSTREAM]     [FIRE +50% damage] |
|  before the orb)            ( HEALTH )+----------------------------------------+( ESSENCE)  Inventory [I]|
|                             (  72   )|STAR 1 · 99% ====star line==== star read|(  55    )      Soul [K]|
|                             ( / 100 )| [1][2][3][4][5][6]  |  [LMB][Shift]     |( / 99   )   Project [N]|
|                              ring=arm|  1  2  3  4  5  6       LMB  Shift     |rings=reflux    Menu [Esc]|
+--------------------------------------------------------------------------------------------------+
```
- **Dock**: 6 skill slots 60 px (was 58) + a divider + strike and shoot slots 48 px; framed with the panel texture. Orbs radius
  62 (was 58) sit just outside the dock's ends, rings outside them (arm ring on health; one reflux ring per affinity, ticks at
  `pain_at` and `burn_at` read from `balance.json`, no longer hard-coded 50 / 80).
- **Slot**: sunken well; stage pips top left, cost top right (blue, red when you cannot afford it, with a blue cast over the
  slot as D4 does), progress to next stage along the bottom, keycap hanging below the slot, a clockwise dark sweep while the
  cast recovery runs (strike: its cooldown; shoot: its reload), red slash when the affinity is locked, pulsing gold frame and gem
  when a construct is due. Empty slots are a dimmed well, not black.
- **Star line** along the dock's top edge: `STAR 1 · 58%`, the line, then the aura read; when the star can ascend the read turns
  gold, pulses and shows the Ascend key as a keycap.
- **Above the dock**: on the left, buff chips (`Stonehide 6s`) and the talent's status lines as chips; in the middle the affinity
  resources on backed strips (Slipstream pips, standing stone count, wind-up bar); over each orb only the warning tags.
- **Plate** (top left): framed; name 20 px gold, talent, star pips, money, where, constructs with a `[B]` keycap. Hidden under
  menus.
- **Target frame**: framed, name 17 px bold, health bar 13 px with the numbers outlined inside, **poise bar added** under it,
  the enemy's statuses inside the frame at the right.
- **Prompt**: a dark band fading out at both ends with gold hairlines; keys as keycaps; moved below the target frame so they
  never touch.
- **Title**: 46 px outlined with gold rules either side over a soft shade (no hard band).
- **Log** (bottom left): 14 px outlined over a soft shade; lines wrap to stay left of the health orb.
- **Key reminders** (bottom right): a right-aligned column `Inventory 28 / 38 kg [I] · Soul [K] · Project [N] · Menu [Esc]`,
  clear of the orb; fades in combat. (Shoot moved to the dock.)
- **Minimap**: framed; unexplored = dark sepia, not black; explored ground and road lighter; `N` marker; caption strip inside
  the frame.
- **Over the world**: enemy bars 6 px (were 5), telegraphs and status pips get a dark under-stroke, Netherecho labels outlined.
- **Combat numbers**: bold serif with a dark outline; a number pops in at 1.3 x and settles over 0.12 s, holds, then fades;
  words are set smaller than numbers.
- **Tooltips**: framed, title 19 px with a rule under it, body 14 px, a 0.25 s rest before opening
  (`hud.tooltip_delay_s`). New tooltips for the strike and shoot slots.

### 3.4 Screens
- **Every menu screen** hides the plate, hints, log, tags, buffs and tracker; the dock stays visible (dimmed by the backdrop) so
  health and essence are always in view, as BG3 keeps its hotbar.
- **Inventory**: sheet grouped under BODY / COMBAT / SOUL / LOAD headings; pack cells are sunken wells with a gold edge on hover
  and a faint warm ground for gear; **15 loot items get their own glyphs** (`icon` key in `items.json`: tusk, plate, cord, sigil,
  seed, mask, stave, hide, shield boss, ash, drum, strongbox, relics case, salvage); abilities tab icons square and tinted by
  affinity, bind buttons 15 px.
- **Bars everywhere** (`UiWidgets.Bar`): caption outlined, so it reads on any fill.
- **Saves**: each slot a framed card; Save / Overwrite and Load buttons of fixed width; title in title case.
- **Controls**: wider panel, two columns, grouped under MOVEMENT / COMBAT / SKILLS / SOUL / SCREENS / TOWN AND PASSAGE; an action
  not in a group (a new one) is listed under OTHER, so nothing bindable can go missing.
- **Ethercosm, shop, tempering, message**: unchanged layouts; new frames, bar captions and HUD hiding.

### 3.5 Not done, proposed for later
1. **A real display font** (an OFL serif such as a Garamond or a Trajan-like capital face from Google Fonts) — needs Brent's yes
   for the download (CLAUDE.md: downloads need his yes each time). The code already takes a font file: `UiTheme.font()` is the
   one place to change.
2. **Pickup labels** in the interface serif (one line in `pickup.gd`, outside this task's files).
3. **Health globe detail** — D4's orbs have a textured liquid and a sculpted bezel; ours are drawn. A generated bezel texture is the
   next step if the drawn one is not enough.
4. **A dedicated `--shot-ui` state for buffs** (none of the current states has a buff running, so the buff chips are not in
   any screenshot) — needs a line in `main.gd`, outside this task's files.

---
## 4. What was built

| File | Change |
|---|---|
| `game/scripts/ui/ui_theme.gd` | type scale, `font(bold)`, `frame(kind)` nine-patch loader with flat fallback, textured Theme (buttons, line edit, scroll bars, tooltips), `section()` heading, contrast fixes |
| `game/scripts/ui/ui_draw.gd` | `outlined`, `text_width`, `keycap`, `rich` / `rich_width` (keycaps inside text), `frame`, `sweep` (cooldown wedge); 15 loot glyphs; `item_icon` reads an item's own `icon` |
| `game/scripts/ui/ui_widgets.gd` | `Icon` draws in a slot well and stays square; `Bar` caption outlined |
| `game/scripts/ui/ui_screen.gd` | `hud_hides()` and `HUD_MENU` |
| `game/scripts/hud.gd` | rewritten layout per 3.3 (public API unchanged: `refresh`, `set_prompt`, `set_nether`, `set_passage`, `announce`, `mouse_over_ui`, `debug_tip`); `ui_at(point)` for tests |
| `game/scripts/float_text.gd` | serif bold, outline, pop, words smaller (`spawn` signature unchanged) |
| `game/scripts/settings_menu.gd` | grouped two-column controls menu |
| `game/scripts/ui/inventory_screen.gd`, `saves_screen.gd` | per 3.4 |
| `game/scripts/ui/ethercosm_screen.gd`, `shop_screen.gd`, `tempering_screen.gd`, `message_screen.gd` | `hud_hides()` |
| `game/data/balance.json` | new `"hud"` block: `log_seconds`, `log_max`, `hints_alpha_in_combat`, `show_untouched_enemy_bars`, `wisp_label_range`, `tooltip_delay_s` |
| `game/data/items.json` | `icon` on 15 loot items |
| `game/assets/ui/*.png` (8) | generated frames; rows in `tools/assets/MANIFEST.csv` |
| `tools/assets/make_ui_textures.py` | the generator (own work, no source images) |
| `game/tests/ui_click_probe.gd` | extended: HUD hit-test on the strike slot vs open ground; controls menu rebind by click + key, Reset to defaults, Close (the player's own `keybinds.cfg` is backed up and restored) |

Nothing a test or the player uses was removed: every HUD readout is still drawn (some moved into tooltips only when it is not a
warning — the satellite rate, the per-affinity reflux numbers); every screen keeps its buttons and interactions.

---
## 5. Before and after

All at 1600 x 900 unless named. `shots/` is outside git; the files are in the `feat/ui-v2` worktree
(`<worktree>/shots/`, the worktree path is in the hand-off report).

| State | Before | After |
|---|---|---|
| HUD mid-fight, slot tooltip | `shots/ui-v1-hud.png` | `shots/ui-v2-hud.png` |
| HUD near death, arm lost, locked | `shots/ui-v1-hud-low.png` | `shots/ui-v2-hud-low.png` |
| HUD two affinities, fire hot, stone | `shots/ui-v1-hud-dual.png` | `shots/ui-v2-hud-dual.png` |
| HUD at 1920 x 1080 | `shots/ui-v1-hud-1920x1080.png` | `shots/ui-v2-hud-1920x1080.png` |
| Stubble, minimap | `shots/ui-v1-stubble.png` | `shots/ui-v2-stubble.png` (and `ui-v2-stubble-1920x1080.png`) |
| Stubble by the Cut House | `shots/ui-v1-stubble-cut.png` | `shots/ui-v2-stubble-cut.png` |
| Combat telegraphs | `shots/ui-v1-combat.png` | `shots/ui-v2-combat.png` |
| Step 4 enemies | `shots/ui-v1-enemies4.png` | `shots/ui-v2-enemies4.png` |
| Water + lightning skills | `shots/ui-v1-skills.png` | `shots/ui-v2-skills.png` |
| Fire heat readout | `shots/ui-v1-fire.png` | `shots/ui-v2-fire.png` |
| Wind Slipstream | `shots/ui-v1-wind.png` | `shots/ui-v2-wind.png` |
| Earth stone / braced | `shots/ui-v1-earth.png` | `shots/ui-v2-earth.png` |
| Netherecho | `shots/ui-v1-nether.png` | `shots/ui-v2-nether.png` |
| Inventory | `shots/ui-v1-inventory.png` | `shots/ui-v2-inventory.png` |
| Inventory at 1920 x 1080 | `shots/ui-v1-inventory-1920x1080.png` | `shots/ui-v2-inventory-1920x1080.png` |
| Inventory, abilities tab | `shots/ui-v1-inventory-abilities.png` | `shots/ui-v2-inventory-abilities.png` |
| Ethercosm | `shots/ui-v1-ethercosm.png`, `-2` | `shots/ui-v2-ethercosm.png`, `-2` |
| Shop | `shots/ui-v1-shop.png` | `shots/ui-v2-shop.png` |
| Tempering yard | `shots/ui-v1-temper.png` | `shots/ui-v2-temper.png` |
| Saves | `shots/ui-v1-saves.png` | `shots/ui-v2-saves.png` |
| Controls | `shots/ui-v1-settings.png` | `shots/ui-v2-settings.png` |
| Town (theme only, out of scope) | `shots/ui-v1-town.png` | `shots/ui-v2-town.png` |
| Creation 1–4, face (theme only) | `shots/ui-v1-create-1..4.png`, `-create-2-face` | `shots/ui-v2-create-1..4.png`, `-create-2-face` |
| Title (= creation 1) | `shots/ui-v1-title.png` | `shots/ui-v2-title.png` |

Note: a passage's biome is rolled per run, so the `hud*` and `nether` pairs show different floors before and after; the HUD is
what to compare.

---
## 6. Decisions for Brent

1. **Font**: keep the system Palatino, or let an agent download one OFL serif from Google Fonts (one file, licence recorded in the
   manifest)? A display face for titles would do the most for the BG3 feel.
2. **Key reminders in combat**: they now fade out completely while a fight is on (`hints_alpha_in_combat` 0). Keep, or leave them
   faint (e.g. 0.35)?
3. **Strike and shoot on the dock**: wanted, or is the bar for skills only?
4. **Enemy bars**: still only on hurt or hovered enemies (`show_untouched_enemy_bars` 0). D4 shows every bar; switch to 1?
5. **Orb tags only when something is wrong**: the calm `reflux 0` / `satellite +1/s` / `arm 100%` labels are gone (the satellite
   and every affinity's reflux are in the essence tooltip). Is that too quiet?
6. **Generated frames**: the corner-bracket panel look — keep, tone down, or go further (a carved / leather look)?

---
## 7. What was and was not tested

**Run and passed** (on the branch, after the last change):
- rules self-test `res://tests/selftest.tscn`: `767 passed, 0 failed`;
- bots: `--bot-full`, `--bot-dungeon`, `--bot-die` all `PASS`;
- windowed click probes: `ui_click_probe` (town) and `-- --field` both `UICLICK: PASS` with the new checks (strike slot counts as
  interface, open ground does not; rebinding Ascend by click + key, Reset to defaults, Close); `creation_probe` `CREATE: PASS`;
- every state in section 5 screenshotted and looked at; no `ERROR` / `SCRIPT ERROR` lines in any run.

**Not tested — needs Brent**:
- how the HUD *feels* in play: whether the recovery sweep, the fading hints, the tooltip delay and the popping numbers help or
  distract; whether the orb tags appear at the right moments;
- the buff chips and the "ready to ascend" star line are drawn by code no screenshot state reaches (no state has a buff running or
  a full star with the aura ready);
- the HUD at aspect ratios other than 16:9 (ultrawide, 16:10) — the layout is anchored to the edges and centre and should hold,
  but it has not been looked at;
- the controls menu with a real keyboard (the probe pushes a synthetic key);
- hovering pack cells for the gold edge (the probe clicks them; the hover look was not captured).
