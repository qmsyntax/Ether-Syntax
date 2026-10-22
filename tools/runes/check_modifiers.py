"""Cross-check skills against the runes that could modify them (Brent 2026-10-22: "make sure the modifications make
sense").

For every drafted skill (design/data-drafts/skills/<affinity>.json) and every rune that could be added to it (the
other base runes of its affinity, and every universal rune), each of the rune's effect ops is classed, using the same
rules as the game's effects_v1 (stat groups and payload parts from game/data/runes.json):
  direct   - the op has something real to act on in this skill
  fallback - it does not, and would only turn into a little extra power
A rune is "direct" on a skill when all its ops are, "partial" when some are, "fallback" when none are.

Reports, per affinity:
  - skills few runes can really change (too narrow to modify);
  - runes that act on few skills (a modifier that rarely means anything);
  - each skill's own good_modifiers that the maths says do nothing, and bad_modifiers that the maths lets through.

Run: python -P -E tools/runes/check_modifiers.py   (writes design/runes-data/modifier-check.md and .json)
"""
import glob
import json
import os
import re
import sys

# --planned: class runes under the rule changes going to the build (2026-10-22), not today's effects_v1:
#   a status the skill already applies adds stacks; jumps arc any hit on to more enemies; braced works on any
#   skill; `through` (ignore front block and shields) works on any hit; every skill has a recovery, so windup
#   always acts; a self buff's or channel's main number counts as its power; poise on any hit adds stagger damage;
#   duration also lengthens the statuses a skill applies.
PLANNED = '--planned' in sys.argv
MAGNITUDE_KINDS = ('self_buff', 'channel')

ROOT = 'E:/Code/lifesteal-crawler'
RUNES = json.load(open(f'{ROOT}/game/data/runes.json', encoding='utf-8'))
P = RUNES['rule_sets']['bond_v1']['interaction_params']['effects_v1']
GROUPS = P['stat_groups']
PARTS = P['payload_parts']


def parse_ops(text):
    ops = []
    for part in [p.strip() for p in (text or '').split(';') if p.strip()]:
        w = part.split()
        if len(w) >= 2 and w[1].startswith('x'):
            ops.append({'op': 'mul', 'group': w[0]})
        elif w[0] == 'status':
            ops.append({'op': 'status', 'id': w[1]})
        elif w[0] in ('shove', 'pull', 'marks', 'jumps', 'pierce'):
            ops.append({'op': w[0]})
        elif w[0] in ('interrupts', 'braced', 'through'):
            ops.append({'op': w[0]})
        elif w[0] == 'bonus':
            ops.append({'op': 'bonus', 'id': w[1]})
        else:
            ops.append({'op': 'unknown', 'text': part})
    return ops


def flatten(d, prefix=''):
    out = {}
    for k, v in d.items():
        key = f'{prefix}{k}'
        if isinstance(v, dict):
            out.update(flatten(v, key + '.'))
        else:
            out[key] = v
    return out


def has_group(fields, kind, group):
    for f in GROUPS.get(group, []):
        name, _, kinds = f.partition('@')
        if kinds and kind not in kinds.split('|'):
            continue
        v = fields.get(name)
        if v not in (None, 0, 0.0, False, ''):
            return True
    return False


def classify(skill, op):
    nums = skill.get('numbers', {})
    fields = flatten(nums)
    kind = skill.get('kind', '')
    payload = [p for p in PARTS if any(k == p or k.startswith(p + '.') for k in fields)]
    o = op['op']
    if PLANNED:
        if o == 'mul':
            if op['group'] == 'windup':
                return True
            if op['group'] == 'poise' and (bool(payload) or any(k in fields for k in ('on_rise.poise', 'on_arrive.poise'))):
                return True     # poise on any hit adds stagger damage
            if op['group'] == 'duration' and any(k.endswith('status') or 'statuses' in k for k in fields):
                return True     # duration also lengthens the statuses the skill applies
            if op['group'] == 'power' and kind in MAGNITUDE_KINDS and any(
                    isinstance(v, (int, float)) and k not in ('cost', 'reflux_per_cost', 'duration')
                    for k, v in fields.items()):
                return True
            return has_group(fields, kind, op['group'])
        if o in ('status', 'jumps', 'through', 'shove', 'pull', 'marks', 'bonus', 'interrupts'):
            return bool(payload)
        if o == 'braced':
            return True
        if o == 'pierce':
            return kind == 'projectile' or bool(payload)
    if o == 'mul':
        return has_group(fields, kind, op['group'])
    if o == 'status':
        already = any(str(v) == op['id'] for k, v in fields.items() if k.endswith('status') or 'statuses' in k)
        return bool(payload) and not already
    if o in ('shove', 'pull', 'marks', 'bonus'):
        return bool(payload)
    if o == 'interrupts':
        return bool(payload) and not any(k.endswith('interrupts') and v for k, v in fields.items())
    if o == 'jumps':
        return kind == 'chain' or 'jumps' in fields
    if o == 'pierce':
        return kind == 'projectile' and not fields.get('pierce')
    if o == 'braced':
        return bool(fields.get('windup')) and not fields.get('braced')
    return False


def main():
    drafts = {}
    for f in sorted(glob.glob(f'{ROOT}/design/data-drafts/skills/*.json')):
        d = json.load(open(f, encoding='utf-8'))
        drafts[d['affinity'].lower()] = d
    base = RUNES['base_runes']
    effects = {}
    for r in base.values():
        effects[r['name']] = r.get('effect') or ''
    for d in drafts.values():
        for name, eff in (d.get('effects') or {}).items():
            if not effects.get(name):
                effects[name] = eff
    universal = [r['name'] for r in RUNES['universal_runes'].values()]
    for r in RUNES['universal_runes'].values():
        effects[r['name']] = r.get('effect') or ''
    by_aff = {}
    for r in base.values():
        by_aff.setdefault(r['affinity'], []).append(r['name'])

    report = {}
    lines = ['# Modifier cross-check', '',
             'Made by `tools/runes/check_modifiers.py`. For each skill, every rune that could be added to it (its '
             "affinity's other base runes and the universal runes) is classed: **direct** (all its ops act on "
             'something real in the skill), **partial**, or **fallback** (none do; it only turns into a little extra '
             'power).', '']
    for aff, d in drafts.items():
        skills = d.get('skills', [])
        rune_hits = {}
        rows = []
        contra_good, contra_bad = [], []
        for s in skills:
            cands = [n for n in by_aff.get(aff, []) if n != s.get('rune')] + universal
            res = {}
            for n in cands:
                ops = parse_ops(effects.get(n))
                if not ops:
                    res[n] = 'no effect'
                    continue
                ok = [classify(s, op) for op in ops]
                res[n] = 'direct' if all(ok) else ('partial' if any(ok) else 'fallback')
                rune_hits.setdefault(n, []).append(res[n] != 'fallback')
            real = sum(1 for v in res.values() if v in ('direct', 'partial'))
            rows.append((s.get('name'), s.get('rune'), s.get('kind'), real, len(res)))
            for g in s.get('good_modifiers', []):
                if res.get(g.get('rune')) == 'fallback':
                    contra_good.append((s.get('name'), g.get('rune'), effects.get(g.get('rune'))))
            for b in s.get('bad_modifiers', []):
                if res.get(b.get('rune')) == 'direct':
                    contra_bad.append((s.get('name'), b.get('rune'), b.get('why', '')[:90]))
            report.setdefault(aff, {})[s.get('id')] = res
        rows.sort(key=lambda r: r[3] / max(r[4], 1))
        lines += [f'## {aff.capitalize()}', '', f'{len(skills)} skills. Share of candidate runes that really change each '
                  'skill, lowest first:', '', '| Skill | Rune | Kind | Runes that act on it |', '|---|---|---|---|']
        for n, ru, k, real, tot in rows:
            lines.append(f'| {n} | {ru} | {k} | {real} of {tot} ({real * 100 // max(tot, 1)}%) |')
        weak = sorted(((n, sum(v), len(v)) for n, v in rune_hits.items() if n in by_aff.get(aff, [])),
                      key=lambda t: t[1] / t[2])[:6]
        lines += ['', "This affinity's runes that act on the fewest of its skills: " +
                  ', '.join(f'{n} {h}/{t}' for n, h, t in weak), '']
        if contra_good:
            lines += ['Listed as good modifiers, but the maths gives them nothing to act on:', '']
            lines += [f'- {a} + {b} (`{e}`)' for a, b, e in contra_good] + ['']
        if contra_bad:
            lines += ['Listed as bad modifiers, but the maths lets them act fully (check the "why"):', '']
            lines += [f'- {a} + {b}: {w}' for a, b, w in contra_bad] + ['']
    os.makedirs(f'{ROOT}/design/runes-data', exist_ok=True)
    tag = '-planned' if PLANNED else ''
    if PLANNED:
        lines.insert(2, '**Planned rules** (`--planned`): classed under the rule changes going to the build, not '
                        "today's effects_v1. See the module docstring.")
    open(f'{ROOT}/design/runes-data/modifier-check{tag}.md', 'w', encoding='utf-8').write('\n'.join(lines) + '\n')
    json.dump(report, open(f'{ROOT}/design/runes-data/modifier-check{tag}.json', 'w', encoding='utf-8'), indent=1)
    print('\n'.join(lines[:12]))
    print('affinities checked:', list(drafts))


if __name__ == '__main__':
    main()
