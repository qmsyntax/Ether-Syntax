"""Force our 16 affinities onto the concept data and list each one's associated words N edges deep (Brent 2026-10-22).

"Make it all there is": every word in the vocabulary is assigned to exactly one of our affinities, the one whose
core it is nearest to through the concept graph. Then each affinity's words are listed by how many edges they sit
from its core, so the candidates for its base runes can be read off.

Graph (over the vocabulary):
  - nearest-neighbour links (K per word) on context-blended vectors:
    alpha * GloVe(word) + (1 - alpha) * mean GloVe of its main WordNet sense's gloss, synonyms, hypernyms,
    related forms, attributes and up to 12 hyponyms;
  - WordNet's own links between vocabulary words, through each word's MAIN sense only (linking through every
    sense let "wind" pull in coil and loop): same synset, derivationally related (+), attribute (=),
    hypernym / hyponym (@ ~), antonym (!), also-see (^), similar-to (&), verb group ($). A target synset reaches a
    vocabulary word when it is among that word's first two senses of its part of speech.
Cores: the affinity name plus pinning words. "earth" (mostly the planet in this data) and "freeze" (mostly halting,
as in freezing assets) were swapped out of the Earth and Ice cores after the first run.
  Edge length = 1 - cosine of the two blended vectors (at least 0.05).
Assignment: shortest weighted path from each affinity's core (multi-source Dijkstra). Depth = edges on that path.
A word whose second-nearest affinity is within MARGIN of its nearest is flagged as shared (a universal candidate).

Run: python -P -E tools/runes/forced_affinities.py [N]   (default N 3; writes design/runes-data/forced-affinities.json
and design/rune-candidates.xlsx)
"""
import heapq
import json
import os
import re
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import wn_glove as W  # noqa: E402

OUT_DIR = 'E:/Code/lifesteal-crawler/design/runes-data'
XLSX = 'E:/Code/lifesteal-crawler/design/rune-candidates.xlsx'
N_DEEP = int(sys.argv[1]) if len(sys.argv) > 1 else 3
FREQ_CUT = 30000
ALPHA = 0.5
K = 8
MARGIN = 0.10

CORES = {  # the affinity's name plus words that pin its meaning (the only hand-chosen input here)
    'Water': ['water', 'flood', 'wave'], 'Fire': ['fire', 'flame', 'burn'], 'Earth': ['soil', 'stone', 'rock'],
    'Wind': ['wind', 'gust', 'breeze'], 'Lightning': ['lightning', 'electricity', 'thunder'],
    'Ice': ['ice', 'frost', 'snow'], 'Dark': ['darkness', 'shadow', 'dark'], 'Metal': ['metal', 'iron', 'steel'],
    'Blood': ['blood', 'bleed', 'vein'], 'Life': ['life', 'heal', 'vitality'], 'Death': ['death', 'die', 'corpse'],
    'Nature': ['plant', 'grow', 'vegetation'], 'Light': ['light', 'shine', 'bright'],
    'Dream': ['dream', 'sleep', 'illusion'], 'Poison': ['poison', 'venom', 'toxic'],
    'Disease': ['disease', 'infection', 'plague'],
}
KEEP = {
    'n': {'noun.phenomenon', 'noun.object', 'noun.substance', 'noun.process', 'noun.state', 'noun.attribute',
          'noun.event', 'noun.body', 'noun.feeling', 'noun.plant'},
    'v': {'verb.weather', 'verb.change', 'verb.emission', 'verb.motion', 'verb.contact', 'verb.body',
          'verb.consumption', 'verb.perception', 'verb.emotion', 'verb.creation'},
    'a': {'adj.all'},
}
LINKS = {'@', '@i', '~', '~i', '+', '=', '!', '^', '&', '$'}


def main():
    lexn = W.lexnames()
    syn = W.synsets(lexn)
    idx = W.index()
    cnt = W.counts()
    gidx, G, rank = W.glove()
    forced = {w for ws in CORES.values() for w in ws}

    # vocabulary: each lemma gets its most-used POS (by tagged counts) and that POS's first sense
    vocab, sense, posof = [], {}, {}
    for lemma, by_pos in idx.items():
        if not re.fullmatch(r'[a-z]+', lemma) or lemma not in gidx:
            continue
        c = cnt.get(lemma, {})
        if lemma not in forced and (rank[lemma] >= FREQ_CUT or sum(c.values()) < 2):
            continue
        pos = max(by_pos, key=lambda p: (c.get(p, 0), {'n': 2, 'v': 1, 'a': 0}[p]))
        key = (pos, by_pos[pos][0])
        if lemma in forced or syn[key]['lex'] in KEEP[pos]:
            vocab.append(lemma)
            sense[lemma] = key
            posof[lemma] = pos
    vocab.sort(key=lambda w: rank[w])
    vi = {w: i for i, w in enumerate(vocab)}
    print('vocabulary', len(vocab), file=sys.stderr)

    def ctx_tokens(w):
        s = syn[sense[w]]
        toks = re.findall(r'[a-z]+', s['gloss'].lower()) + [x for x in s['words'] if x != w]
        hypo = []
        for sym, p, o in s['ptrs']:
            if (p, o) not in syn:
                continue
            if sym in ('@', '@i', '+', '='):
                toks += syn[(p, o)]['words']
            elif sym in ('~', '~i'):
                hypo.append(syn[(p, o)]['words'][0])
        return toks + hypo[:12]

    base = np.vstack([G[gidx[w]] for w in vocab])
    ctx = np.vstack([v if v is not None else base[i] for i, v in enumerate(
        (lambda vs: (np.mean(vs, 0) / np.linalg.norm(np.mean(vs, 0))) if vs else None)(
            [G[gidx[t]] for t in ctx_tokens(w) if t in gidx and t not in W.STOP]) for w in vocab)])
    X = ALPHA * base + (1 - ALPHA) * ctx
    X /= np.linalg.norm(X, axis=1, keepdims=True)

    # graph
    adj = [dict() for _ in vocab]

    def link(a, b, kind):
        if a == b:
            return
        d = max(0.05, 1 - float(X[a] @ X[b]))
        for x, y in ((a, b), (b, a)):
            if y not in adj[x] or adj[x][y][0] > d:
                adj[x][y] = (d, kind)
    S = X @ X.T
    np.fill_diagonal(S, -1)
    nn = np.argsort(-S, axis=1)[:, :K]
    for i in range(len(vocab)):
        for j in nn[i]:
            link(i, int(j), 'near')
    reach = {}   # synset -> vocabulary words that have it among their first two senses
    for w in vocab:
        for o in idx[w][posof[w]][:2]:
            reach.setdefault((posof[w], o), []).append(w)
    for a in vocab:
        s = syn[sense[a]]
        for b in reach.get(sense[a], []):
            link(vi[a], vi[b], 'synonym')
        for sym, p, o in s['ptrs']:
            if sym in LINKS and (p, o) in reach:
                for b in reach[(p, o)]:
                    link(vi[a], vi[b], {'!': 'opposite', '+': 'related form', '=': 'attribute'}.get(sym, 'wordnet'))

    # multi-source Dijkstra per affinity
    affs = list(CORES)
    INF = 1e9
    dist = np.full((len(affs), len(vocab)), INF)
    hops = np.full((len(affs), len(vocab)), -1, dtype=int)
    via = [[None] * len(vocab) for _ in affs]
    for ai, a in enumerate(affs):
        pq = []
        for w in CORES[a]:
            i = vi[w]
            dist[ai, i], hops[ai, i] = 0.0, 0
            heapq.heappush(pq, (0.0, i))
        while pq:
            d, i = heapq.heappop(pq)
            if d > dist[ai, i]:
                continue
            for j, (w, kind) in adj[i].items():
                nd = d + w
                if nd < dist[ai, j]:
                    dist[ai, j], hops[ai, j], via[ai][j] = nd, hops[ai, i] + 1, (vocab[i], kind)
                    heapq.heappush(pq, (nd, j))

    # every word to its nearest affinity ("all there is"); unreachable words fall back to cosine with the cores
    core_vec = np.vstack([X[[vi[w] for w in CORES[a]]].mean(0) for a in affs])
    core_vec /= np.linalg.norm(core_vec, axis=1, keepdims=True)
    result = {a: [] for a in affs}
    shared = []
    for i, w in enumerate(vocab):
        col = dist[:, i]
        order = np.argsort(col)
        if col[order[0]] >= INF:
            sims = core_vec @ X[i]
            order = np.argsort(-sims)
            best, second, how = order[0], order[1], 'cosine'
            margin = float(sims[best] - sims[second])
        else:
            best, second, how = order[0], order[1], 'graph'
            margin = float((col[second] - col[best]) / max(col[second], 1e-9)) if col[second] < INF else 1.0
        a = affs[best]
        sims_all = core_vec @ X[i]
        spec = float(sims_all[best] - sims_all.mean())
        entry = {'specificity': round(spec, 3), 'word': w, 'pos': posof[w], 'depth': int(hops[best, i]), 'distance': round(float(col[best]), 3),
                 'second': affs[second], 'margin': round(margin, 3), 'via': via[best][i],
                 'gloss': syn[sense[w]]['gloss'], 'category': syn[sense[w]]['lex'], 'assigned_by': how}
        result[a].append(entry)
        if margin < MARGIN and w not in CORES[a]:
            shared.append((w, a, affs[second], round(margin, 3)))
    for a in affs:
        result[a].sort(key=lambda e: e['distance'])

    os.makedirs(OUT_DIR, exist_ok=True)
    json.dump({'method': {'alpha': ALPHA, 'k': K, 'freq_cut': FREQ_CUT, 'margin': MARGIN, 'n_deep': N_DEEP,
                          'cores': CORES, 'vocabulary': len(vocab)},
               'affinities': result, 'shared': shared},
              open(f'{OUT_DIR}/forced-affinities.json', 'w', encoding='utf-8'), indent=1)

    # workbook for Brent: summary + one sheet per affinity (words up to N deep)
    from openpyxl import Workbook
    from openpyxl.styles import Font, PatternFill, Alignment
    wb = Workbook()
    sm = wb.active
    sm.title = 'Summary'
    hdr = Font(name='Arial', bold=True, color='FFFFFF')
    fill = PatternFill('solid', fgColor='2F2A24')
    body = Font(name='Arial', size=10)
    cols = ['Affinity', 'Core words', 'Words assigned (all)', f'Within {N_DEEP} edges', f'Verbs within {N_DEEP}',
            f'Top verbs within {N_DEEP} edges']
    for c, h in enumerate(cols, 1):
        x = sm.cell(row=1, column=c, value=h)
        x.font, x.fill = hdr, fill
    for r, a in enumerate(affs, 2):
        near = [e for e in result[a] if 0 <= e['depth'] <= N_DEEP]
        verbs = [e['word'] for e in near if e['pos'] == 'v']
        vals = [a, ', '.join(CORES[a]), len(result[a]), len(near), len(verbs), ', '.join(verbs[:25])]
        for c, v in enumerate(vals, 1):
            x = sm.cell(row=r, column=c, value=v)
            x.font, x.alignment = body, Alignment(wrap_text=True, vertical='top')
    r = len(affs) + 3
    sm.cell(row=r, column=1, value='Shared (second affinity within 10%: universal-rune candidates)').font = Font(name='Arial', bold=True)
    for k, (w, a, b, m) in enumerate(sorted(shared, key=lambda t: t[3])[:200]):
        for c, v in enumerate([w, a, b, m], 1):
            sm.cell(row=r + 1 + k, column=c, value=v).font = body
    for c, wdt in zip('ABCDEF', (12, 30, 12, 12, 12, 110)):
        sm.column_dimensions[c].width = wdt
    sm.freeze_panes = 'B2'
    note = sm.cell(row=r + 203, column=1, value=(
        f'Made by tools/runes/forced_affinities.py from WordNet 3.0 and GloVe 6B. Every word in a vocabulary of '
        f'{len(vocab)} is assigned to the nearest of our 16 affinities through a concept graph; depth is edges from the '
        'affinity\'s core words. pos: n noun, v verb, a adjective. Regenerating overwrites this file.'))
    note.font = Font(name='Arial', size=9, italic=True)
    names = {'n': 'noun', 'v': 'verb', 'a': 'adjective'}
    for a in affs:
        ws = wb.create_sheet(a)
        heads = ['Word', 'Part of speech', 'Depth (edges)', 'Distance', 'Specificity', 'Reached from', 'Link',
                 'Next-nearest affinity', 'Margin', 'Meaning (WordNet)', 'WordNet category']
        for c, h in enumerate(heads, 1):
            x = ws.cell(row=1, column=c, value=h)
            x.font, x.fill = hdr, fill
        rr = 2
        for e in result[a]:
            if not 0 <= e['depth'] <= N_DEEP:
                continue
            vals = [e['word'], names[e['pos']], e['depth'], e['distance'], e['specificity'], e['via'][0] if e['via'] else '(core)',
                    e['via'][1] if e['via'] else '', e['second'], e['margin'], e['gloss'], e['category']]
            for c, v in enumerate(vals, 1):
                ws.cell(row=rr, column=c, value=v).font = body
            rr += 1
        for c, wdt in zip('ABCDEFGHIJK', (16, 11, 9, 9, 10, 16, 13, 14, 8, 70, 18)):
            ws.column_dimensions[c].width = wdt
        ws.freeze_panes = 'B2'
        ws.auto_filter.ref = f'A1:K{max(rr - 1, 1)}'
    wb.save(XLSX)
    for a in affs:
        near = [e for e in result[a] if 0 <= e['depth'] <= N_DEEP]
        print(f"{a:10s} all={len(result[a]):4d} <= {N_DEEP}: {len(near):4d}  verbs: " +
              ' '.join(e['word'] for e in near if e['pos'] == 'v')[:150])
    print('shared', len(shared))


if __name__ == '__main__':
    main()
