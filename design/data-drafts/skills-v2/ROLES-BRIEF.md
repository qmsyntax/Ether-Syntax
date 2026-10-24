# Brief: rebuild every affinity's skills and runes around its role (2026-10-24)

Brent's request: "now we need to rebuild all the skills / runes around the new roles and add the new functionality.
Big task. Make it happen." The framework is `design/affinities/framework.md`: 8 bases and 10 hybrids, each
hybrid with two parents, each affinity with one role. Until now every affinity has been a generalist: about 10
skills on its 10 base runes, all doing a bit of everything. Each affinity must now **play its role**, and each
hybrid must read as its two parents' child.

## Read first

| File | What it gives you |
|---|---|
| `CLAUDE.md` | Project rules. Original names only; no canon characters, story or the books' ability names; no book text. Skills never hurt their caster; Blood never pays in health. |
| `design/affinities/framework.md` | The 18 affinities, their parents and roles. **This is the spec.** |
| `design/data-drafts/skills/BRIEF.md` | The first drafting brief: the skill entry format, number bands, the effect syntax. **Use the same format.** |
| `design/data-drafts/skills/<affinity>.json` / `.md` | The current drafts (2026-10-22), 176 skills. Start from these. |
| `game/data/runes.json` | Every base rune: id, name, meaning, opposite, role, valence, electronegativity, effect; plus the universal runes and the five-axis affinity positions. Read only. |
| `design/14-rune-sets-v0.md`, `design/13-runes-v0.md` | The rune system. Section 2 has the chemistry: role sets valence, and electronegativity = 2.5 + draw x spread. Sections 7-12 have the rulings. |
| `game/data/abilities.json`, `statuses.json` | What the game has now: real field names, kinds and statuses. |

## Rules for the rebuild

1. **The role leads.** About 7 of every 10 skills serve the affinity's role directly. The rest give range and
   utility, so no affinity is helpless; a tank still has a way to reach a runner.
   - Each affinity keeps **three starters**: one ranged, one close, one movement. Each starter is shaped by the role
     (a tank's "ranged" starter can be a taunt or a pull).
2. **Hybrids are their parents' child.** A hybrid's skills visibly combine its parents' natures:
   - Lightning is Fire's burst with Wind's speed;
   - Metal is Earth's ground forged by Fire;
   - Holy is Light plus Life.

   For each hybrid skill, say in `verb_fit` which parent trait it carries. A hybrid's rune set should likewise draw on
   its parents' concepts, while staying its own.
3. **The skill is the verb.** Each skill is still built on one base rune of its affinity, and must do what that rune
   means (BRIEF.md).
4. **Runes may change.** Rename, re-mean, add or drop base runes so the set serves the role. Constraints:
   - Every base rune has an **opposite** within its affinity; they come in a/b pairs.
   - Each affinity has **10 to 12** base runes.
   - Keep the rune chemistry: role (cap, link, branch, frame) and draw. Keep a kept rune's role and draw unless the
     role demands otherwise, and say why.
   - Effects use the effect syntax, 1 to 3 ops each.
   - Universal runes are not yours to change.
5. **New affinities: Holy (Light + Life) and Unholy (Dark + Death)** need a full set: base runes, effects, skills and
   an affinity rule.
6. **Role mechanics are welcome and expected.** Define each once in `new_mechanics` with a one-line rule, in the
   data-driven style: generic keys, not one-off code. For example:
   - taunt / threat, so enemies go for you;
   - wards and shields;
   - buffs on yourself and your summons (there are no party allies);
   - weapon coating for Poison: your weapon hits and ranged shots carry a payload for a time;
   - conjured weapons for Blood;
   - stealth / unseen for Dark;
   - auras, life-drain and healing over time.

   Reuse existing statuses and kinds wherever one fits. Check statuses.json first.
7. **Ascension boosts** (Brent 2026-10-24) are built separately. At each new star, every skill gets a permanent
   boost the player puts into one of its aspects: damage/healing, reach, speed or an essence discount. Make sure each
   skill's `numbers` have the fields those aspects act on (a power number, a reach/range/radius, a speed or duration,
   and a cost).
8. **Numbers:** the bands in BRIEF.md. A role may shift its bands with a reason (a tank's hits are lighter and its
   cost tiers lower; a burst caster's are heavier and dearer).

## Output (only these files; touch nothing else, do not commit)

For each affinity you are given, in `design/data-drafts/skills-v2/`:
- **`<affinity>.json`:** the BRIEF.md format, `{"affinity", "parents": [..] or [], "role", "reflux_tier", "rule", "skills": [...], "effects": {...}}`. Mark each skill's `status` as `existing | changed | new | dropped`, and keep `id` for existing ones. List dropped skills with the reason.
- **`<affinity>-runes.json`:** the full revised base rune set, as `[{"id": existing id or "new", "name", "meaning", "opposite": name, "role", "draw", "effect", "change": "kept | renamed | re-meant | new | dropped", "why"}]`. Draw is a number from -1 to 1, as in design/14.
- **`<affinity>.md`:** a short readable summary:
  - the role in one line;
  - how each parent shows (hybrids);
  - a table of skill, rune, kind, what it does, and whether it is a starter;
  - the rune changes;
  - the new mechanics.

## Report
- the files written;
- skill and rune counts per affinity;
- every new mechanic;
- every rune renamed or dropped;
- anything you were unsure of.
