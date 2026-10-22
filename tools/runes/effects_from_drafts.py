"""Effects for every base rune (new affinities from the drafts, fixes for the five game affinities) and the skills on
each rune, from design/data-drafts/skills. Writes effects_v2.csv for the Excel write."""
import csv
import glob
import json

FIXES = {   # rune: new effect, with why (from the cross-check and the water/fire/earth/wind designer's notes)
    'Burn': ('status alight 2', 'Burn and Ignite were the same op; Burn is now the heavy one'),
    'Float': ('shove +1; poise x0.8', 'copied wind\'s Lift (status aloft); a lightened body flies further'),
    'Drain': ('pull +1; reflux x0.9', 'duplicated Dry (bonus soaked); "draw in" is a pull'),
    'Buffer': ('duration x1.2; reflux x0.85', '"cushioning air" did not mean faster wind-ups'),
    'Lull': ('interrupts; speed x0.85', '"dead air; shots drop" had become a reflux cut'),
    'Root': ('braced; poise x1.2', 'braced alone acted on no earth skill'),
    'Seep': ('through', 'pierce only acted on bolts; seeping water gets behind shields on any hit'),
    'Tunnel': ('through; reach x1.1', 'pierce only acted on bolts; passing through ground'),
    'Collapse': ('status pinned; poise x1.3', 'a 1 s stun on any payload was too strong for a modifier'),
    'Overrun': ('poise x1.4; through', 'disease skills carry no poise; overwhelming defences gets past them'),
    'Drop': ('poise x1.4; interrupts', 'few wind skills carry poise; a slam also breaks a wind-up'),
}


def main():
    skills_on, effects = {}, {}
    for f in sorted(glob.glob('E:/Code/lifesteal-crawler/design/data-drafts/skills/*.json')):
        d = json.load(open(f, encoding='utf-8'))
        for s in d['skills']:
            label = s['name'] + (' (starter)' if s.get('starter') else '') + (' (new)' if s.get('status') == 'new' else '')
            skills_on.setdefault(s['base_rune'], []).append(label)
        for name, eff in (d.get('effects') or {}).items():
            effects[name] = (eff, '')
    for name, fx in FIXES.items():
        effects[name] = fx
    with open('C:/Users/qmsyntax/AppData/Local/Temp/claude/E--/030d1be6-e370-46d9-bc4f-8172e6305d16/scratchpad/runes/effects_v2.csv',
              'w', newline='', encoding='utf-8') as fh:
        w = csv.writer(fh)
        w.writerow(['kind', 'key', 'value', 'note'])
        for name, (eff, why) in effects.items():
            w.writerow(['effect', name, eff, why])
        for rid, names in skills_on.items():
            w.writerow(['skills', rid, ', '.join(names), ''])
    print(len(effects), 'effects;', len(skills_on), 'runes with skills;', sum(len(v) for v in skills_on.values()), 'skills')


main()
