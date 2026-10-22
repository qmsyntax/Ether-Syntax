"""Per affinity: core words, the most specific verbs the data assigns to it, and WordNet antonyms for each candidate.

Feeds the hand-checked revised rune set (design/runes-data/revised-rune-set.md). Reads forced-affinities.json, so run
forced_affinities.py first.  Run: python -P -E tools/runes/rune_candidates.py
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import wn_glove as W  # noqa: E402

D = 'E:/Code/lifesteal-crawler/design/runes-data'


def main():
    data = json.load(open(f'{D}/forced-affinities.json', encoding='utf-8'))
    home = {e['word']: a for a, es in data['affinities'].items() for e in es}
    syn = W.synsets(W.lexnames())
    idx = W.index()

    def antonyms(word):
        out = []
        for pos in ('v', 'a', 'n'):
            for o in idx.get(word, {}).get(pos, [])[:3]:
                s = syn[(pos, o)]
                for sym, p, oo in s['ptrs']:
                    if sym == '!' and (p, oo) in syn:
                        out += syn[(p, oo)]['words'][:2]
        return sorted(set(out) - {word})[:4]

    out = {}
    for a, es in data['affinities'].items():
        cores = data['method']['cores'][a]
        verbs = sorted([e for e in es if e['pos'] == 'v' and e['word'] not in cores], key=lambda e: -e['specificity'])[:30]
        out[a] = {
            'cores': [(c, antonyms(c)) for c in cores],
            'verbs': [(e['word'], round(e['specificity'], 2), antonyms(e['word']),
                       [(x, home.get(x)) for x in antonyms(e['word'])]) for e in verbs]}
    json.dump(out, open(f'{D}/rune-candidates.json', 'w', encoding='utf-8'), indent=1)
    for a, v in out.items():
        print(f"\n{a}: cores " + ', '.join(f"{c}{'<->' + '/'.join(an) if an else ''}" for c, an in v['cores']))
        print('  ' + '; '.join(f"{w}{'<->' + '/'.join(an) if an else ''}" for w, s, an, _ in v['verbs'][:24]))


if __name__ == '__main__':
    main()
