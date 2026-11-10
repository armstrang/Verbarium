#!/usr/bin/env python3
"""Checks the Verbarium deck (mobile/assets/deck/*.txt): format, one gap per sentence, no word twice.

Core files: word|pos|meaning|sentence          (the rank comes from the file name, 1-… to 5-…)
Banner files (toefl.txt, ielts.txt): rank|word|pos|meaning|sentence
A word may be written american/british. Run from the repository root:  python3 content/tools/check_deck.py
"""
import glob, os, re, sys

POS = {"n", "v", "adj", "adv", "prep", "conj"}
root = os.path.join(os.path.dirname(__file__), "..", "..", "mobile", "assets", "deck")
bad, seen, counts = [], {}, {}
for path in sorted(glob.glob(os.path.join(root, "*.txt"))):
    name = os.path.basename(path)
    layer = "core" if name[0].isdigit() else name[:-4]
    for ln, line in enumerate(open(path, encoding="utf-8"), 1):
        line = line.rstrip("\n")
        if not line or line.startswith("#"):
            continue
        f = line.split("|")
        if layer == "core":
            rank = int(name[0])
        else:
            if not f[0].isdigit():
                bad.append(f"{name}:{ln} no rank"); continue
            rank, f = int(f[0]), f[1:]
        if len(f) != 4:
            bad.append(f"{name}:{ln} {len(f)} fields"); continue
        word, pos, meaning, sent = f
        if pos not in POS: bad.append(f"{name}:{ln} pos {pos}")
        if sent.count("___") != 1: bad.append(f"{name}:{ln} gaps {sent.count('___')}")
        if not meaning.strip(): bad.append(f"{name}:{ln} no meaning")
        if not re.fullmatch(r"[a-z]+(/[a-z]+)?", word): bad.append(f"{name}:{ln} word {word!r}")
        for w in word.split("/"):
            if re.search(rf"\b{w}\b", sent.lower()): bad.append(f"{name}:{ln} answer in sentence: {w}")
            key = (w, layer if layer != "core" else "core")
            for other in ("core", layer):
                if (w, other) in seen: bad.append(f"{name}:{ln} twice: {w} (also {seen[(w, other)]})")
            seen[key] = f"{name}:{ln}"
        if not sent.rstrip().endswith((".", "?", "!")): bad.append(f"{name}:{ln} no full stop")
        counts[(layer, rank)] = counts.get((layer, rank), 0) + 1
for k in sorted(counts): print(k, counts[k])
print("core", sum(v for (l, _), v in counts.items() if l == "core"),
      "toefl", sum(v for (l, _), v in counts.items() if l == "toefl"),
      "ielts", sum(v for (l, _), v in counts.items() if l == "ielts"))
print("\n".join(bad) if bad else "deck ok")
sys.exit(1 if bad else 0)
