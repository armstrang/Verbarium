"""Applies c1c2_meanings.txt: each `word|meaning` replaces the Indonesian meaning of that word in the deck file that
holds it (core files: field 3; banner files: field 4, after the rank). Prints how many lines changed."""
import glob
import os

here = os.path.dirname(os.path.abspath(__file__))
deck = os.path.join(here, '..', '..', 'mobile', 'assets', 'deck')
new = {}
for line in open(os.path.join(here, 'c1c2_meanings.txt'), encoding='utf-8'):
    line = line.rstrip('\n')
    if not line or line.startswith('#'):
        continue
    w, m = line.split('|', 1)
    new[w] = m
changed = 0
for f in sorted(glob.glob(os.path.join(deck, '*.txt'))):
    name = os.path.basename(f)
    if name == 'collocations.txt':
        continue
    banner = name in ('toefl.txt', 'ielts.txt')
    out = []
    for line in open(f, encoding='utf-8').read().split('\n'):
        p = line.split('|')
        if line and not line.startswith('#') and len(p) > 3:
            i = 1 if banner else 0
            w = p[i].split('/')[0]
            if w in new and p[i + 2] != new[w]:
                p[i + 2] = new[w]
                line = '|'.join(p)
                changed += 1
        out.append(line)
    open(f, 'w', encoding='utf-8').write('\n'.join(out))
print(changed, 'meanings changed')
