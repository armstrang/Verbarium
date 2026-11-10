#!/usr/bin/env python3
"""Puts English definitions where they belong.

Definitions are written as `word|definition` lines in any file, in any order. This reads the files given and
writes each line into mobile/assets/deck/en/<the deck file that holds the word>, keeping the order of the deck
file. A word that is in both banner files gets its definition in both. Lines for words that are in no deck file
are reported. Run from the repository root:  python3 content/tools/place_defs.py staging.txt [more.txt]
"""
import glob, os, sys

root = "mobile/assets/deck"
where, order = {}, {}
for path in sorted(glob.glob(os.path.join(root, "*.txt"))):
    name = os.path.basename(path)
    if name == "collocations.txt":
        continue
    banner = name in ("toefl.txt", "ielts.txt")
    order[name] = []
    for line in open(path, encoding="utf-8"):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        f = line.split("|")
        word = f[1] if banner else f[0]
        order[name].append(word)
        where.setdefault(word.split("/")[0], []).append((name, word))

defs = {}
for name in order:  # what is already placed
    p = os.path.join(root, "en", name)
    if os.path.exists(p):
        for line in open(p, encoding="utf-8"):
            line = line.rstrip("\n")
            if line and not line.startswith("#") and "|" in line:
                w, d = line.split("|", 1)
                defs[w.split("/")[0]] = d
unknown = []
for path in sys.argv[1:]:
    for line in open(path, encoding="utf-8"):
        line = line.rstrip("\n")
        if not line or line.startswith("#") or "|" not in line:
            continue
        w, d = line.split("|", 1)
        w = w.split("/")[0].strip()
        if w in where:
            defs[w] = d.strip()
        else:
            unknown.append(w)
os.makedirs(os.path.join(root, "en"), exist_ok=True)
done = 0
for name, words in order.items():
    lines = [f"{w}|{defs[w.split('/')[0]]}" for w in words if w.split("/")[0] in defs]
    done += len(lines)
    p = os.path.join(root, "en", name)
    if lines:
        open(p, "w", encoding="utf-8").write(f"# Verbarium — plain English definitions for {name}: word|definition\n" + "\n".join(lines) + "\n")
print("placed", done, "of", sum(len(v) for v in order.values()))
if unknown:
    print("not in the deck:", " ".join(unknown))
