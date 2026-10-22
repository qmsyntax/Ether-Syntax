"""Greenfield element discovery with a WordNet context layer (Brent 2026-10-22).

Run 2 (discover_affinities.py) found the elemental affinities collapsed into one "weather and elements" domain.
This run narrows to the physical world and blends a context layer into each word before clustering:

  word vector = alpha * GloVe(word) + (1 - alpha) * context
  context     = mean GloVe of the word's main WordNet sense: its gloss words, synonyms, hypernym words,
                derivationally related forms (+) and attribute links (=)

Vocabulary: nouns whose most-used sense (WordNet tagged counts) is a natural phenomenon, natural object, substance
or process, plus weather verbs; single tokens among the 50,000 most frequent GloVe words.

The elemental PROBE groups below are never used to build vectors or seed clusters. They only score each setting:
  purity   - for each group, the share of its words that land in its most common cluster
  distinct - the share of groups whose most common cluster no other group claims
Every setting in the grid is reported, so the choice can be checked.

Run: python -P -E tools/runes/discover_elements.py   (writes design/runes-data/element-discovery.json)
"""
import itertools
import json
import os
import re
import sys

import numpy as np

RAW = 'E:/Code/passage-data/raw'
WN = RAW + '/wordnet'
OUT_DIR = 'E:/Code/lifesteal-crawler/design/runes-data'
FREQ_CUT = 50000
SEED = 11
DOMAINS = {
    'narrow': {'noun.phenomenon', 'noun.object', 'noun.substance', 'noun.process', 'verb.weather'},
    'wide': {'noun.phenomenon', 'noun.object', 'noun.substance', 'noun.process', 'verb.weather', 'noun.state',
             'noun.attribute', 'noun.event', 'verb.emission', 'verb.change'},
    'wide+time': {'noun.phenomenon', 'noun.object', 'noun.substance', 'noun.process', 'verb.weather', 'noun.state',
                  'noun.attribute', 'noun.event', 'verb.emission', 'verb.change', 'noun.time'},
}
VARIANT = sys.argv[1] if len(sys.argv) > 1 else 'wide'
DOMAIN = DOMAINS[VARIANT]
STOP = set('a an the of or and to in on at by for with from as is are be that which this it its into than such '
           'used any one two other more most some especially usually often being made something can very not '
           'esp etc e g also when where who whose what having has have was were their them they there'.split())
PROBES = {
    'fire': 'fire flame burn burning blaze ember ash smoke combustion inferno spark scorch',
    'water': 'water rain river sea ocean wave flood tide stream lake splash wet',
    'earth': 'earth rock stone soil mud sand mountain dirt clay boulder gravel dust',
    'wind': 'wind air breeze gust gale storm hurricane tornado blow draft',
    'lightning': 'lightning thunder electricity spark bolt static charge thunderstorm',
    'light': 'light sun sunlight glow shine radiance brightness ray beam dawn',
    'dark': 'dark darkness shadow night dusk gloom shade twilight',
    'ice': 'ice snow frost freeze cold glacier hail sleet blizzard chill',
}


def load_lexnames():
    return {int(l.split()[0]): l.split()[1] for l in open(f'{WN}/lexnames', encoding='utf-8')}


def load_synsets(lexnames):
    """(pos, offset) -> {lex, words, ptrs: [(sym, pos, offset)], gloss}"""
    syn = {}
    for pos, fn in (('n', 'noun'), ('v', 'verb'), ('a', 'adj')):
        for line in open(f'{WN}/data.{fn}', encoding='utf-8', errors='replace'):
            if line.startswith('  '):
                continue
            head, _, gloss = line.partition(' | ')
            p = head.split()
            off, lex = p[0], lexnames[int(p[1])]
            wcnt = int(p[3], 16)
            words = [p[4 + 2 * i].lower() for i in range(wcnt)]
            j = 4 + 2 * wcnt
            pcnt = int(p[j])
            ptrs = []
            for q in range(pcnt):
                sym, poff, ppos = p[j + 1 + 4 * q], p[j + 2 + 4 * q], p[j + 3 + 4 * q]
                ptrs.append((sym, 'a' if ppos in ('a', 's') else ppos, poff))
            syn[(pos, off)] = {'lex': lex, 'words': words, 'ptrs': ptrs, 'gloss': gloss.split(';')[0]}
    return syn


def load_index():
    """lemma -> list of (pos, offset) in WordNet's sense order (most frequent first), per POS."""
    idx = {}
    for pos, fn in (('n', 'noun'), ('v', 'verb')):
        for line in open(f'{WN}/index.{fn}', encoding='utf-8'):
            if line.startswith('  '):
                continue
            p = line.split()
            lemma, scnt, pcnt = p[0], int(p[2]), int(p[3])
            offs = p[4 + pcnt + 2:]
            idx.setdefault(lemma, []).extend((pos, o) for o in offs[:scnt])
    return idx


def load_counts():
    """lemma -> total tagged uses (all senses), for a 'really used' check."""
    c = {}
    for line in open(f'{WN}/cntlist.rev', encoding='utf-8'):
        key, _, cnt = line.split()
        lem = key.split('%')[0]
        c[lem] = c.get(lem, 0) + int(cnt)
    return c


def load_glove():
    words, vecs, rank = [], [], {}
    with open(f'{RAW}/glove.6B.300d.txt', encoding='utf-8') as f:
        for i, line in enumerate(f):
            if i >= 200000:
                break
            w, rest = line.split(' ', 1)
            words.append(w)
            vecs.append(np.array(rest.split(), dtype=np.float32))
            rank[w] = i
    v = np.vstack(vecs)
    v /= np.linalg.norm(v, axis=1, keepdims=True)
    return {w: i for i, w in enumerate(words)}, v, rank


def kmeans(x, k, rng, iters=80, restarts=8):
    best, bi = None, np.inf
    for _ in range(restarts):
        cent = x[rng.choice(len(x), k, replace=False)]
        for _ in range(iters):
            lab = ((x[:, None, :] - cent[None]) ** 2).sum(-1).argmin(1)
            new = np.vstack([x[lab == j].mean(0) if (lab == j).any() else cent[j] for j in range(k)])
            if np.allclose(new, cent):
                break
            cent = new
        inertia = ((x - cent[lab]) ** 2).sum()
        if inertia < bi:
            best, bi = lab, inertia
    return best


def laplacian_eig(X, knn):
    S = X @ X.T
    np.fill_diagonal(S, -1)
    n = len(X)
    nn = np.argsort(-S, axis=1)[:, :knn]
    W = np.zeros((n, n), dtype=np.float32)
    r = np.repeat(np.arange(n), knn)
    W[r, nn.ravel()] = np.clip(S[r, nn.ravel()], 0, None)
    W = np.maximum(W, W.T)
    d = 1 / np.sqrt(np.maximum(W.sum(1), 1e-9))
    return np.linalg.eigh(np.eye(n, dtype=np.float32) - d[:, None] * W * d[None, :])


def score(labels, vocab_pos):
    groups = {}
    for g, ws in PROBES.items():
        labs = [labels[vocab_pos[w]] for w in ws.split() if w in vocab_pos]
        if len(labs) < 3:
            continue
        vals, cnts = np.unique(labs, return_counts=True)
        groups[g] = (int(vals[cnts.argmax()]), float(cnts.max() / len(labs)), len(labs))
    if not groups:
        return 0, 0, groups
    purity = float(np.mean([p for _, p, _ in groups.values()]))
    home = [c for c, _, _ in groups.values()]
    distinct = float(np.mean([home.count(c) == 1 for c in home]))
    return purity, distinct, groups


def main():
    rng = np.random.default_rng(SEED)
    lexnames = load_lexnames()
    syn = load_synsets(lexnames)
    index = load_index()
    counts = load_counts()
    gidx, G, rank = load_glove()

    def gvec(tokens):
        vs = [G[gidx[t]] for t in tokens if t in gidx and t not in STOP]
        if not vs:
            return None
        m = np.mean(vs, 0)
        return m / np.linalg.norm(m)

    vocab, main_sense = [], {}
    for lemma, senses in index.items():
        if not re.fullmatch(r'[a-z]+', lemma) or lemma not in gidx or rank[lemma] >= FREQ_CUT:
            continue
        if counts.get(lemma, 0) < 2:
            continue
        first = senses[0]                      # the lemma's most frequent sense (any POS listed first)
        if syn[first]['lex'] in DOMAIN:
            vocab.append(lemma)
            main_sense[lemma] = first
    vocab = sorted(set(vocab), key=lambda w: rank[w])
    print('vocabulary', len(vocab), file=sys.stderr)

    ctx = {}
    for w in vocab:
        s = syn[main_sense[w]]
        toks = re.findall(r'[a-z]+', s['gloss'].lower()) + [x for x in s['words'] if x != w]
        for sym, ppos, poff in s['ptrs']:
            if sym in ('@', '@i', '+', '=') and (ppos, poff) in syn:
                toks += syn[(ppos, poff)]['words']
        hypo = [syn[(ppos, poff)]['words'][0] for sym, ppos, poff in s['ptrs'] if sym in ('~', '~i') and (ppos, poff) in syn]
        toks += hypo[:12]
        ctx[w] = gvec(toks)
    base = np.vstack([G[gidx[w]] for w in vocab])
    ctxm = np.vstack([ctx[w] if ctx[w] is not None else base[i] for i, w in enumerate(vocab)])
    pos = {w: i for i, w in enumerate(vocab)}

    results = []
    cache = {}
    for alpha, knn in itertools.product((1.0, 0.7, 0.5, 0.3), (10, 15)):
        X = alpha * base + (1 - alpha) * ctxm
        X /= np.linalg.norm(X, axis=1, keepdims=True)
        evals, evecs = laplacian_eig(X, knn)
        gaps = np.diff(evals[:41])
        k_gap = int(np.argmax(gaps[5:40]) + 6)
        for k in sorted({k_gap, 8, 10, 12, 14, 16, 20, 24, 28, 32, 40}):
            U = evecs[:, :k] / np.maximum(np.linalg.norm(evecs[:, :k], axis=1, keepdims=True), 1e-9)
            lab = kmeans(U, k, rng)
            pur, dis, groups = score(lab, pos)
            results.append({'alpha': alpha, 'knn': knn, 'k': k, 'k_by_eigengap': k == k_gap, 'purity': round(pur, 3),
                            'distinct': round(dis, 3), 'score': round(pur * dis, 3),
                            'groups': {g: {'cluster': c, 'purity': round(p, 2), 'n': n} for g, (c, p, n) in groups.items()}})
            cache[(alpha, knn, k)] = (lab, X)
    results.sort(key=lambda r: -r['score'])
    best = results[0]
    lab, X = cache[(best['alpha'], best['knn'], best['k'])]
    clusters = []
    for c in range(best['k']):
        mem = [w for w in vocab if lab[pos[w]] == c]
        if not mem:
            continue
        cen = X[[pos[m] for m in mem]].mean(0)
        cen /= np.linalg.norm(cen)
        central = sorted(mem, key=lambda w: -float(X[pos[w]] @ cen))
        probes_here = [g for g, v in best['groups'].items() if v['cluster'] == c]
        clusters.append({'cluster': c, 'size': len(mem), 'probe_groups': probes_here, 'central': central[:24],
                         'common': sorted(mem, key=lambda w: rank[w])[:24]})
    clusters.sort(key=lambda x: -x['size'])
    os.makedirs(OUT_DIR, exist_ok=True)
    json.dump({'variant': VARIANT, 'domain': sorted(DOMAIN), 'vocabulary': len(vocab), 'grid': results, 'best': {k: v for k, v in best.items()},
               'best_clusters': clusters}, open(f'{OUT_DIR}/element-discovery-{VARIANT}.json', 'w', encoding='utf-8'), indent=1)
    print('best', best['alpha'], best['knn'], best['k'], best['purity'], best['distinct'])


if __name__ == '__main__':
    main()
