# Combat-review probe (2026-11-03)

This probe backs `design/combat-review-2026-11-03.md` (section 8). It changes no game code or data; the what-if
knobs change numbers in memory for one run only. The Godot scripts live in the game, at `game/tests/combat_review/`
(moved there on 2026-11-03 so the probe is kept with the build it measures); the batch and table tools live here.

## Files

| File | What it is |
|---|---|
| `game/tests/combat_review/run.gd` | A SceneTree launcher. It loads `driver.gd` (the probe); run with `-s res://tests/combat_review/run.gd` |
| `game/tests/combat_review/driver.gd` | The probe: a real, non-invulnerable character and a scripted careful player |
| `game/tests/combat_review/meter.gd` | A read-only TalentEffect appended to `player.effects`: it sees every hit dealt and taken |
| `batch.sh` | Runs one config per line, ONE Godot at a time, and appends `PROBE {json}` lines to the output file |
| `compare.py` | The before -> after table of the review's targets, one column per results file |
| `aggregate.py` | Means by place / tier / policy, the engaged histogram, rewards per minute and TTK |
| `summarise.py` | Per-run table, press outcomes, refusal lines, per-skill hit rates and damage sources |
| `configs-*.txt` | The run lists used for the review (`fast` = arena + passage, `stubble`, `whatif`) |
| `results-*.jsonl` | Raw data kept with the repo (see below) |

## Rerun

Run these from Git Bash, from the repo root. Never start two at once (the batch runs one Godot at a time).

```
bash tools/combat-review/batch.sh tools/combat-review/configs-fast.txt    /tmp/out.jsonl   # arena + passage, ~8 min
bash tools/combat-review/batch.sh tools/combat-review/configs-stubble.txt /tmp/out.jsonl   # the Stubble, ~4 min
python -I tools/combat-review/compare.py tools/combat-review/results-2026-11-03-before.jsonl /tmp/out.jsonl
python -I tools/combat-review/aggregate.py /tmp/out.jsonl
python -I tools/combat-review/summarise.py /tmp/out.jsonl
```

`batch.sh` appends to the output file (default `tools/combat-review/results.jsonl`, ignored by git), and writes
`last-run.log` and `batch-times.log` beside it, so use a fresh file per batch.

## One run

```
<console exe> --headless --fixed-fps 60 --path game -s res://tests/combat_review/run.gd -- --scenario=arena --aff=water --meditate=1 --minutes=8
```

## Arguments

| Argument | Values | Default | What it does |
|---|---|---|---|
| `--scenario=` | `stubble` \| `arena` \| `passage` | | Where the character fights |
| `--aff=` | one of the 8 bases | | The character's affinity |
| `--skills=` | `a,b` | the first two roots | The two starting skills |
| `--tier=` | `new` \| `mid` | `new` | `mid` = 2 stars (99+40), the kit plus the first tier-2 skill, stage 2, Dim Mote, Iron Knuckles |
| `--meditate=` | `0` \| `1` | | `1` sits to a full tank between fights |
| `--rest=` | a fraction | `0.7` | Health to rest up to between fights |
| `--press=` | `careful` \| `eager` | `careful` | `eager` also presses unaffordable skills once a second |
| `--dodge=` | `walk` \| `dash` | `walk` | `dash` uses the movement skill to step out of telegraphs |
| `--lines=1` | | | Also steps off archer aim lines |
| `--minutes=` | | | Cap on game minutes |
| `--waves=` | | | Arena wave cap |
| `--walls=` | | | Passage wall cap |
| `--whatif_hp=` | `M` | | Every enemy kind's hp x M (in memory only) |
| `--whatif_strike_essence=` | `N` | | Each landed bare strike gives N essence (a generator) |
| `--whatif_sat=` | `N` | | Satellite essence per second |
| `--tag=` | | | A label for the output line |

## Limits

These are also in the doc, section 8.3:

- A "hit" is damage carrying the skill's id within 2 s; Glint's 0 hits is probably a meter gap.
- After a death in the passage, `walls_cleared` reads 0, because the game resets it in town.
- The Stubble walker can stick (the run then ends as "stuck").
- Runs are not deterministic (enemy rolls, the bake order), so read small groups (1-2 runs) as direction only.
- It proves nothing about feel.
