"""Hidden property profiles for every rune, computed from language (Brent 2026-10-22).

Each rune is placed on ten meaning axes. An axis is defined by two sets of plain words for its two ends (a semantic
differential, the "SemAxis" method): a rune's score is how much nearer its meaning lies to one end than the other.
A rune's meaning vector blends its name's GloVe vector with the mean vector of its meaning sentence from the rune
workbook, so a name with several senses ("Lance", "Seal") is read the way the rune uses it. The runes are read from
game/data/runes.json - the workbook's own export (tools/runes/export_runes_json.py) - so this never opens the workbook
(2026-10-24: the workbook is Brent's, read only, through the exporter).
Scores are centred per axis, scaled by one spread shared by all axes, and squashed to -1..+1.

Run: python -P -E tools/runes/rune_properties.py   (writes design/runes-data/rune-properties.json)
"""
import json
import os
import re
import sys

from pathlib import Path

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import wn_glove as W  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
RUNES = ROOT / 'game/data/runes.json'
OUT = ROOT / 'design/runes-data/rune-properties.json'
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
    # 2026-10-24: the v2 runes (renamed and new pairs, and Holy and Unholy) [MODEL]
    'Heave': 'force', 'Catch': 'extent', 'Weigh': 'binding', 'Floe': 'motion', 'Thirst': 'motion', 'Bestow': 'direction',
    'Bid': 'binding', 'Herd': 'binding', 'Prism': 'extent', 'Charm': 'binding', 'Steep': 'duration', 'Exhume': 'direction',
    'Ward': 'form', 'Bless': 'vitality', 'Penance': 'binding', 'Exile': 'direction', 'Wrath': 'force', 'Zeal': 'motion',
    'Outpour': 'direction', 'Daunt': 'direction', 'Gloom': 'extent', 'Torment': 'duration', 'Stalk': 'binding',
}


def main():
    gidx, G, _ = W.glove(400000)

    def vec(text):
        toks = [t for t in re.findall(r'[a-z]+', text.lower()) if t in gidx and t not in W.STOP]
        if not toks:
            return None
        m = np.mean([G[gidx[t]] for t in toks], 0)
        return m / np.linalg.norm(m)

    data = json.loads(RUNES.read_text(encoding='utf-8'))
    runes = []
    opp = {}
    for rid, r in data['base_runes'].items():
        runes.append({'id': rid, 'affinity': str(r['affinity']).capitalize(), 'name': r['name'], 'meaning': str(r.get('meaning', ''))})
        opp[rid] = r.get('opposite', '')
    for rid, r in data['universal_runes'].items():
        runes.append({'id': rid, 'affinity': 'Universal', 'name': r['name'], 'meaning': str(r.get('meaning', ''))})
        opp[rid] = r.get('opposite', '')

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
    json.dump(out, open(OUT, 'w', encoding='utf-8', newline='\n'), indent=1)
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
