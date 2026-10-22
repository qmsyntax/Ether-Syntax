"""Hidden property profiles for every rune, computed from language (Brent 2026-10-22).

Each rune is placed on ten meaning axes. An axis is defined by two sets of plain words for its two ends (a semantic
differential, the "SemAxis" method): a rune's score is how much nearer its meaning lies to one end than the other.
A rune's meaning vector blends its name's GloVe vector with the mean vector of its meaning sentence from the rune
workbook, so a name with several senses ("Lance", "Seal") is read the way the rune uses it.
Scores are centred per axis, scaled by one spread shared by all axes, and squashed to -1..+1.

Run: python -P -E tools/runes/rune_properties.py   (writes design/runes-data/rune-properties.json)
"""
import json
import os
import re
import sys

import numpy as np
from openpyxl import load_workbook

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import wn_glove as W  # noqa: E402

WB = 'E:/Code/lifesteal-crawler/design/runes-workbook.xlsx'
OUT = 'E:/Code/lifesteal-crawler/design/runes-data/rune-properties.json'
NAME_WEIGHT = 0.5
AXES = {
    'heat': ('hot heat burn fire warm scorch blaze', 'cold freeze ice chill frost cool frozen'),
    'motion': ('move fast rush flow swift speed race', 'still stop rest halt stillness static motionless'),
    'force': ('push strike crush blast force slam smash', 'gentle soft delicate weak ease light tender'),
    'form': ('build solid structure harden shape forge form', 'break shatter dissolve crumble decay melt scatter'),
    'vitality': ('life heal grow alive birth vigor living', 'death kill die rot corpse dead perish'),
    'light': ('light bright shine glow reveal visible radiant', 'dark shadow hide conceal obscure gloom darkness'),
    'mind': ('mind thought dream imagine perceive feel memory', 'body flesh matter physical material muscle bone'),
    'extent': ('spread wide expand everywhere vast widespread broad', 'focus narrow point single concentrate small precise'),
    'duration': ('linger last persist endure lasting long remain', 'instant sudden brief quick flash momentary abrupt'),
    'binding': ('bind hold join grip attach tie fasten', 'release sever free loosen detach cut separate'),
    'direction': ('outward emit release expel radiate push spill', 'inward absorb draw pull suck take gather'),
}
# Each opposite pair's defining axis and which rune is its plus end (designed: the data reads a pair's topic well
# but not which end each rune is at - "darken" and "lighten" are both simply about light to it). The pair is set
# to +/-PAIR_STRENGTH on that axis (or its data value, if stronger); every other axis stays as the data has it.
PAIR_STRENGTH = 0.8
PAIR_AXES = {
    'Flood': 'direction', 'Surge': 'force', 'Soak': 'direction', 'Float': 'vitality', 'Gush': 'force',
    'Sweep': 'motion', 'Splash': 'extent', 'Wave': 'force',
    'Burn': 'heat', 'Ignite': 'heat', 'Explode': 'direction', 'Blaze': 'extent', 'Flare': 'light',
    'Raise': 'form', 'Harden': 'form', 'Quake': 'motion', 'Dig': 'light', 'Collapse': 'binding',
    'Blow': 'motion', 'Lash': 'force', 'Drop': 'force', 'Carry': 'motion', 'Whirl': 'binding',
    'Strike': 'force', 'Discharge': 'direction', 'Arc': 'binding', 'Quicken': 'motion', 'Thunder': 'force',
    'Thaw': 'heat', 'Frost': 'binding', 'Melt': 'heat', 'Rime': 'form', 'Toughen': 'form',
    'Lighten': 'light', 'Expose': 'light', 'Shadowstep': 'motion', 'Resound': 'force', 'Disgorge': 'direction',
    'Forge': 'form', 'Fuse': 'binding', 'Seal': 'binding', 'Hone': 'force', 'Plate': 'form',
    'Bleed': 'direction', 'Spill': 'direction', 'Clot': 'binding', 'Pulse': 'motion', 'Breathe': 'vitality',
    'Heal': 'vitality', 'Renew': 'motion', 'Strengthen': 'force', 'Cure': 'vitality', 'Regrow': 'form',
    'Spare': 'vitality', 'Animate': 'motion', 'Preserve': 'form', 'Haunt': 'duration', 'Manifest': 'light',
    'Grow': 'extent', 'Sprout': 'vitality', 'Flourish': 'vitality', 'Sow': 'direction', 'Tangle': 'binding',
    'Shine': 'light', 'Glow': 'duration', 'Radiate': 'direction', 'Clarity': 'mind', 'Reflect': 'form',
    'Wake': 'motion', 'Conjure': 'form', 'Dread': 'force', 'Unmask': 'light', 'Whisper': 'direction',
    'Purge': 'vitality', 'Cleanse': 'vitality', 'Neutralise': 'form', 'Linger': 'duration', 'Stimulate': 'force',
    'Disinfect': 'vitality', 'Spread': 'extent', 'Fester': 'duration', 'Billow': 'extent', 'Overrun': 'force',
    'Motion': 'motion', 'Delay': 'duration', 'Curve': 'extent', 'Fall': 'force', 'Expand': 'extent',
    'Far': 'extent', 'Scatter': 'extent', 'Many': 'extent', 'Without': 'direction', 'Elsewhere': 'motion',
    'Persist': 'duration', 'Hold': 'binding', 'Repeat': 'duration', 'Before': 'mind', 'Bind': 'binding',
    'Repel': 'direction', 'Give': 'direction', 'Other': 'direction', 'Order': 'form', 'Pure': 'vitality',
    'Reveal': 'light', 'Fury': 'force', 'Will': 'force', 'Remember': 'mind', 'Reflux': 'heat',
    'Life': 'vitality', 'Soul': 'mind', 'Fate': 'binding',
}


def main():
    gidx, G, _ = W.glove(400000)

    def vec(text):
        toks = [t for t in re.findall(r'[a-z]+', text.lower()) if t in gidx and t not in W.STOP]
        if not toks:
            return None
        m = np.mean([G[gidx[t]] for t in toks], 0)
        return m / np.linalg.norm(m)

    wb = load_workbook(WB, read_only=True, data_only=True)
    runes = []
    base = wb['Base Runes']
    meaning = {}
    for name in [s for s in wb.sheetnames if s not in ('Read Me', 'Affinities', 'Alignment', 'Base Runes',
                                                      'Universal Runes', 'Bond Rules', 'Slider Links')]:
        for r in wb[name].iter_rows(min_row=6, values_only=True):
            if r[1] and re.fullmatch(r'[A-Z]{3}-\d+[ab]', str(r[1])):
                meaning[r[1]] = str(r[4] or '')
    for r in base.iter_rows(min_row=2, values_only=True):
        if r[0]:
            runes.append({'id': r[0], 'affinity': r[1], 'name': r[3], 'meaning': meaning.get(r[0], '')})
    for r in wb['Universal Runes'].iter_rows(min_row=2, values_only=True):
        if r[0]:
            runes.append({'id': r[0], 'affinity': 'Universal', 'name': r[1], 'meaning': str(r[6] or '')})
    opp = {r[0]: r[5] for r in base.iter_rows(min_row=2, values_only=True) if r[0]}
    opp.update({r[0]: r[3] for r in wb['Universal Runes'].iter_rows(min_row=2, values_only=True) if r[0]})

    axes = {}
    for ax, (pos, neg) in AXES.items():
        axes[ax] = (vec(pos), vec(neg))
    raw = np.zeros((len(runes), len(AXES)))
    for i, ru in enumerate(runes):
        nv = vec(ru['name'])
        mv = vec(ru['meaning'])
        parts = [p for p in ((nv, NAME_WEIGHT), (mv, 1 - NAME_WEIGHT)) if p[0] is not None]
        v = sum(p[0] * p[1] for p in parts)
        v /= np.linalg.norm(v)
        for j, (pv, ngv) in enumerate(axes.values()):
            raw[i, j] = float(v @ pv - v @ ngv)
    # centre each axis, but scale all axes by one shared spread: a per-axis scale inflated axes the data barely
    # separates (it made Kill "mind" and Darken hardly "dark")
    z = (raw - raw.mean(0)) / raw.std()
    prof = np.tanh(z / 1.5)
    names = list(AXES)
    pos_of = {ru['id']: i for i, ru in enumerate(runes)}
    defining = {}
    for i, ru in enumerate(runes):
        if ru['name'] not in PAIR_AXES:
            continue
        j = names.index(PAIR_AXES[ru['name']])
        k = pos_of[opp[ru['id']]]
        prof[i, j] = max(PAIR_STRENGTH, prof[i, j])
        prof[k, j] = min(-PAIR_STRENGTH, prof[k, j])
        defining[ru['id']] = defining[runes[k]['id']] = PAIR_AXES[ru['name']]
    missing = [ru['name'] for ru in runes if ru['id'] not in defining]
    if missing:
        sys.exit(f'pairs with no defining axis: {missing}')
    for ru in runes:
        ru['pair_axis'] = defining[ru['id']]
    out = {'method': __doc__.strip().splitlines()[0], 'axes': {k: {'plus': v[0], 'minus': v[1]} for k, v in AXES.items()},
           'runes': [{**ru, 'profile': {ax: round(float(prof[i, j]), 3) for j, ax in enumerate(AXES)}}
                     for i, ru in enumerate(runes)]}
    json.dump(out, open(OUT, 'w', encoding='utf-8'), indent=1)
    by = {ru['name']: prof[i] for i, ru in enumerate(runes)}
    for n in ['Burn', 'Freeze', 'Heal', 'Kill', 'Shine', 'Darken', 'Explode', 'Seal', 'Surge', 'Tangle', 'Dream',
              'Sleep', 'Gush', 'Settle', 'Linger', 'Flash', 'Spread', 'Focus', 'Bind', 'Sever']:
        if n in by:
            top = sorted(zip(names, by[n]), key=lambda t: -abs(t[1]))[:3]
            print(f'{n:9s} ' + '  '.join(f'{a} {v:+.2f}' for a, v in top))
    for j, ax in enumerate(names):
        order = np.argsort(prof[:, j])
        print(f'{ax:9s} +: ' + ', '.join(runes[i]['name'] for i in order[-6:][::-1]) + '   -: ' +
              ', '.join(runes[i]['name'] for i in order[:6]))


if __name__ == '__main__':
    main()
