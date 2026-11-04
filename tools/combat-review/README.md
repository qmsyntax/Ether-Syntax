# Combat-review probe (2026-11-03)

This probe backs `E:\Code\lifesteal-crawler\design\combat-review-2026-11-03.md`. It changes no game code or data.
The what-if knobs change numbers in memory for one run only.

## Files

| File | What it is |
|---|---|
| `run.gd` | A SceneTree launcher. It loads `driver.gd` (the probe) and runs with `-s` against `game/` |
| `meter.gd` | A read-only TalentEffect appended to `player.effects`: it sees every hit dealt and taken |
| `batch.sh` | Runs one config per line, ONE Godot at a time, and appends `PROBE {json}` lines to `results.jsonl` |
| `aggregate.py` | Means by place / tier / policy, the engaged histogram, rewards per minute and TTK |
| `summarise.py` | Per-run table, press outcomes, refusal lines, per-skill hit rates and damage sources |
| `configs-*.txt` | The run lists used for the review |
| `results-*.jsonl` | The raw data the review's tables were built from |

## Rerun

Run these from Git Bash. Never start two at once.

```
cd /c/Users/qmsyntax/AppData/Local/Temp/claude/3c515764271446d6/030d1be6-e370-46d9-bc4f-8172e6305d16/scratchpad/combat-review
bash batch.sh configs-fast.txt       # arena + passage, ~10 min
bash batch.sh configs-stubble.txt    # Stubble, ~10-60 min (it runs at about real time headless)
bash batch.sh configs-whatif.txt     # the what-if runs
python -I aggregate.py results.jsonl
python -I summarise.py results.jsonl
```

`batch.sh` appends to `results.jsonl`, so empty or rename that file between batches.

## One run

```
G="$(ls "$LOCALAPPDATA"/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_*/Godot_v4.7.2-stable_win64_console.exe)"
"$G" --headless --fixed-fps 60 --path E:/Code/lifesteal-crawler/game -s "<this dir>/run.gd" -- --scenario=arena --aff=water --meditate=1 --minutes=8
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
- It proves nothing about feel.
