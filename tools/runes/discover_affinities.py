"""Greenfield affinity discovery (Brent 2026-10-22): which natural concept clusters exist, before we force any list?

Data (downloaded with Brent's yes, kept outside the repo in E:/Code/passage-data/raw):
  - WordNet 3.0 dictionary files (Princeton, WordNet licence): word categories (lexicographer files) and how often
    each word sense is used in tagged text (cntlist.rev).
  - GloVe 6B 300d (Stanford NLP, public domain / PDDL): word vectors.

Method, fixed before looking at results (v2: filters added after v1 showed junk, see the commit log):
  1. Candidate words: single-token lowercase words among the 40,000 most frequent GloVe words that WordNet's tagged
     text uses mostly as a noun (>= 50% of tagged uses, >= 2 noun uses), whose most-used noun sense is in one of the
     lexicographer files for natural phenomena, substances, states, processes, body, feelings, plants and animals.
  2. A k-nearest-neighbour graph over their GloVe vectors (cosine), symmetrised.
  3. Spectral clustering; the number of clusters is picked from the eigengap of the normalised graph Laplacian.
  4. Level 2: every level-1 cluster is clustered again the same way (2-12 sub-clusters, by eigengap).
  5. Clusters are named by their most central words; our affinity names are mapped onto them.

Run: python -P -E tools/runes/discover_affinities.py   (writes design/runes-data/affinity-discovery.json)
"""
import json
import os
import re
import sys

import numpy as np

RAW = 'E:/Code/passage-data/raw'
OUT_DIR = 'E:/Code/lifesteal-crawler/design/runes-data'
FREQ_CUT = 40000
KNN = 12
SEED = 7

LEXNAMES_KEEP = {'noun.phenomenon', 'noun.substance', 'noun.state', 'noun.process', 'noun.body',
                 'noun.feeling', 'noun.plant', 'noun.animal'}
OURS = ['water', 'fire', 'earth', 'wind', 'lightning', 'ice', 'dark', 'metal', 'blood', 'life', 'death', 'nature',
        'light', 'dream', 'poison', 'disease']
PROPOSED = ['sound', 'gravity', 'space', 'time', 'mind', 'beast', 'spirit']


def load_lexnames():
    names = {}
    for line in open(f'{RAW}/wordnet/lexnames', encoding='utf-8'):
        num, name, _ = line.split()
        names[int(num)] = name
    return names


def usage(lexnames):
    """lemma -> {'pos': {n/v/a/r: count}, 'noun_lex': {lexname: count}} from tagged-text counts."""
    out = {}
    pos_of = {'1': 'n', '2': 'v', '3': 'a', '4': 'r', '5': 'a'}
    for line in open(f'{RAW}/wordnet/cntlist.rev', encoding='utf-8'):
        key, _, cnt = line.split()
        lemma, rest = key.split('%')
        ss_type, lexnum = rest.split(':')[0], int(rest.split(':')[1])
        e = out.setdefault(lemma, {'pos': {}, 'noun_lex': {}})
        p = pos_of[ss_type]
        e['pos'][p] = e['pos'].get(p, 0) + int(cnt)
        if p == 'n':
            ln = lexnames[lexnum]
            e['noun_lex'][ln] = e['noun_lex'].get(ln, 0) + int(cnt)
    return out


def load_glove(extra):
    words, vecs, rank = [], [], {}
    with open(f'{RAW}/glove.6B.300d.txt', encoding='utf-8') as f:
        for i, line in enumerate(f):
            w, rest = line.split(' ', 1)
            if i < FREQ_CUT or w in extra:
                words.append(w)
                vecs.append(np.array(rest.split(), dtype=np.float32))
                rank[w] = i
    v = np.vstack(vecs)
    v /= np.linalg.norm(v, axis=1, keepdims=True)
    return words, v, rank


def kmeans(x, k, rng, iters=100, restarts=10):
    best, best_inertia = None, np.inf
    for _ in range(restarts):
        cent = x[rng.choice(len(x), k, replace=False)]
        for _ in range(iters):
            d = ((x[:, None, :] - cent[None, :, :]) ** 2).sum(-1)
            lab = d.argmin(1)
            new = np.vstack([x[lab == j].mean(0) if (lab == j).any() else cent[j] for j in range(k)])
            if np.allclose(new, cent):
                break
            cent = new
        inertia = ((x - cent[lab]) ** 2).sum()
        if inertia < best_inertia:
            best, best_inertia = lab, inertia
    return best


def spectral(X, rng, kmin, kmax):
    """Labels for rows of X (unit vectors), k chosen by the eigengap within [kmin, kmax]."""
    n = len(X)
    knn = min(KNN, n - 1)
    S = X @ X.T
    np.fill_diagonal(S, -1)
    nn = np.argsort(-S, axis=1)[:, :knn]
    W = np.zeros((n, n), dtype=np.float32)
    rows = np.repeat(np.arange(n), knn)
    W[rows, nn.ravel()] = np.clip(S[rows, nn.ravel()], 0, None)
    W = np.maximum(W, W.T)
    dinv = 1 / np.sqrt(np.maximum(W.sum(1), 1e-9))
    L = np.eye(n, dtype=np.float32) - dinv[:, None] * W * dinv[None, :]
    evals, evecs = np.linalg.eigh(L)
    kmax = min(kmax, n - 1)
    gaps = np.diff(evals[:kmax + 1])
    k = int(np.argmax(gaps[kmin - 1:kmax]) + kmin)
    U = evecs[:, :k]
    U = U / np.maximum(np.linalg.norm(U, axis=1, keepdims=True), 1e-9)
    return kmeans(U, k, rng), k, [round(float(e), 4) for e in evals[:min(30, n)]]


def describe(members, X, sel_idx, rank, usage_):
    mv = X[[sel_idx[m] for m in members]]
    cen = mv.mean(0)
    cen /= np.linalg.norm(cen)
    central = sorted(members, key=lambda w: -float(X[sel_idx[w]] @ cen))
    lex = {}
    for m in members:
        top = max(usage_[m]['noun_lex'].items(), key=lambda kv: kv[1])[0]
        lex[top] = lex.get(top, 0) + 1
    return {'size': len(members), 'central': central[:20], 'by_frequency': sorted(members, key=lambda w: rank[w])[:20],
            'categories': dict(sorted(lex.items(), key=lambda kv: -kv[1])), 'centroid': cen}


def main():
    rng = np.random.default_rng(SEED)
    lexnames = load_lexnames()
    use = usage(lexnames)
    words, vec, rank = load_glove(set(OURS + PROPOSED))
    idx = {w: i for i, w in enumerate(words)}

    def keep(w):
        if not re.fullmatch(r'[a-z]+', w) or rank[w] >= FREQ_CUT or w not in use:
            return False
        e = use[w]
        n = e['pos'].get('n', 0)
        if n < 2 or n < 0.5 * sum(e['pos'].values()):
            return False
        top = max(e['noun_lex'].items(), key=lambda kv: kv[1])[0]
        return top in LEXNAMES_KEEP
    sel = [w for w in words if keep(w)]
    sel_idx = {w: i for i, w in enumerate(sel)}
    X = vec[[idx[w] for w in sel]]
    print('candidates', len(sel), file=sys.stderr)

    lab1, k1, ev1 = spectral(X, rng, 4, 40)
    print('level 1 k =', k1, file=sys.stderr)
    level1 = []
    for c in range(k1):
        members = [sel[i] for i in range(len(sel)) if lab1[i] == c]
        if not members:
            continue
        d = describe(members, X, sel_idx, rank, use)
        d['id'] = f'L1-{c}'
        sub = []
        if len(members) >= 24:
            Xs = X[[sel_idx[m] for m in members]]
            lab2, k2, _ = spectral(Xs, rng, 2, 12)
            for s in range(k2):
                sm = [members[i] for i in range(len(members)) if lab2[i] == s]
                if sm:
                    ds = describe(sm, X, sel_idx, rank, use)
                    ds['id'] = f'L1-{c}.{s}'
                    sub.append(ds)
            sub.sort(key=lambda x: -x['size'])
        d['sub'] = sub
        level1.append(d)
    level1.sort(key=lambda x: -x['size'])

    flat2 = [s for d in level1 for s in (d['sub'] or [d])]

    def nearest(word, pool, top=3):
        v = vec[idx[word]]
        return [(round(s, 3), cid) for s, cid in sorted(((float(v @ c['centroid']), c['id']) for c in pool), reverse=True)[:top]]

    mapping = {}
    for w in OURS + PROPOSED:
        if w not in idx:
            mapping[w] = None
            continue
        mapping[w] = {'candidate': w in sel_idx, 'nearest_level1': nearest(w, level1), 'nearest_level2': nearest(w, flat2)}

    os.makedirs(OUT_DIR, exist_ok=True)

    def strip(c):
        o = {k: v for k, v in c.items() if k not in ('centroid', 'sub')}
        if c.get('sub'):
            o['sub'] = [strip(s) for s in c['sub']]
        return o
    out = {'method': {'freq_cut': FREQ_CUT, 'knn': KNN, 'level1_k': k1, 'lexnames': sorted(LEXNAMES_KEEP),
                      'candidates': len(sel), 'level1_eigenvalues': ev1},
           'level1': [strip(c) for c in level1], 'ours': mapping,
           'name_similarity': {a: {b: round(float(vec[idx[a]] @ vec[idx[b]]), 3) for b in OURS} for a in OURS}}
    json.dump(out, open(f'{OUT_DIR}/affinity-discovery.json', 'w', encoding='utf-8'), indent=1)
    print('level1', k1, 'level2 total', len(flat2))


if __name__ == '__main__':
    main()
