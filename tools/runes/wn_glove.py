"""Shared loaders for the rune data tools: WordNet 3.0 dictionary files and GloVe 6B 300d vectors.

Raw data lives outside the repo in E:/Code/passage-data/raw (downloaded with Brent's yes, 2026-10-22):
WordNet (Princeton, WordNet licence) and GloVe (Stanford NLP, PDDL).
"""
import re

import numpy as np

RAW = 'E:/Code/passage-data/raw'
WN = RAW + '/wordnet'
STOP = set('a an the of or and to in on at by for with from as is are be that which this it its into than such '
           'used any one two other more most some especially usually often being made something can very not '
           'esp etc e g also when where who whose what having has have was were their them they there'.split())


def lexnames():
    return {int(l.split()[0]): l.split()[1] for l in open(f'{WN}/lexnames', encoding='utf-8')}


def synsets(lexn):
    """(pos, offset) -> {lex, words, ptrs: [(sym, pos, offset)], gloss}. pos is n, v or a (satellites are a)."""
    syn = {}
    for pos, fn in (('n', 'noun'), ('v', 'verb'), ('a', 'adj')):
        for line in open(f'{WN}/data.{fn}', encoding='utf-8', errors='replace'):
            if line.startswith('  '):
                continue
            head, _, gloss = line.partition(' | ')
            p = head.split()
            off, lex = p[0], lexn[int(p[1])]
            wcnt = int(p[3], 16)
            words = [re.sub(r'\(.*\)$', '', p[4 + 2 * i]).lower() for i in range(wcnt)]
            j = 4 + 2 * wcnt
            pcnt = int(p[j])
            ptrs = []
            for q in range(pcnt):
                sym, poff, ppos = p[j + 1 + 4 * q], p[j + 2 + 4 * q], p[j + 3 + 4 * q]
                ptrs.append((sym, 'a' if ppos in ('a', 's') else ppos, poff))
            syn[(pos, off)] = {'lex': lex, 'words': words, 'ptrs': ptrs, 'gloss': gloss.split(';')[0].strip()}
    return syn


def index():
    """lemma -> {pos: [offsets in sense order, most frequent first]}"""
    idx = {}
    for pos, fn in (('n', 'noun'), ('v', 'verb'), ('a', 'adj')):
        for line in open(f'{WN}/index.{fn}', encoding='utf-8'):
            if line.startswith('  '):
                continue
            p = line.split()
            lemma, scnt, pcnt = p[0], int(p[2]), int(p[3])
            offs = p[4 + pcnt + 2:]
            idx.setdefault(lemma, {})[pos] = offs[:scnt]
    return idx


def counts():
    """lemma -> {pos: tagged uses}"""
    pos_of = {'1': 'n', '2': 'v', '3': 'a', '4': 'r', '5': 'a'}
    c = {}
    for line in open(f'{WN}/cntlist.rev', encoding='utf-8'):
        key, _, cnt = line.split()
        lem, rest = key.split('%')
        p = pos_of[rest.split(':')[0]]
        c.setdefault(lem, {})
        c[lem][p] = c[lem].get(p, 0) + int(cnt)
    return c


def glove(limit=200000):
    words, vecs, rank = [], [], {}
    with open(f'{RAW}/glove.6B.300d.txt', encoding='utf-8') as f:
        for i, line in enumerate(f):
            if i >= limit:
                break
            w, rest = line.split(' ', 1)
            words.append(w)
            vecs.append(np.array(rest.split(), dtype=np.float32))
            rank[w] = i
    v = np.vstack(vecs)
    v /= np.linalg.norm(v, axis=1, keepdims=True)
    return {w: i for i, w in enumerate(words)}, v, rank
